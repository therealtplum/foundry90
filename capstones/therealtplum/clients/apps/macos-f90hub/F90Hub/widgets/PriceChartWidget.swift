//
//  PriceChartWidget.swift
//  FMHubControl
//
//  Interactive price chart widget using SwiftUI Charts
//

import SwiftUI
import Charts
import F90Shared

struct PriceChartWidget: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel = MarketDataViewModel()
    @State private var selectedTimeframe: Timeframe = .days30
    @State private var chartType: ChartType = .line
    
    enum Timeframe: String, CaseIterable {
        case days7 = "7D"
        case days30 = "30D"
        case days90 = "90D"
        case days365 = "1Y"
        
        var days: Int {
            switch self {
            case .days7: return 7
            case .days30: return 30
            case .days90: return 90
            case .days365: return 365
            }
        }
    }
    
    enum ChartType: String, CaseIterable {
        case line = "Line"
        case candlestick = "Candlestick"
        case area = "Area"
    }
    
    var body: some View {
        BaseWidgetView(
            title: "Price Charts",
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            actions: AnyView(
                HStack(spacing: 8) {
                    // Timeframe selector
                    Picker("", selection: $selectedTimeframe) {
                        ForEach(Timeframe.allCases, id: \.self) { timeframe in
                            Text(timeframe.rawValue).tag(timeframe)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 60)
                    .onChange(of: selectedTimeframe) {
                        // Timeframe change filters local data, no need to refresh from API
                    }
                    
                    // Chart type selector
                    Picker("", selection: $chartType) {
                        ForEach(ChartType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 80)
                    
                    Button(action: {
                        Task { await viewModel.refresh() }
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(themeManager.textSoftColor)
                }
                .padding(.trailing, 36)
            )
        ) {
            if let selected = viewModel.selectedInstrument {
                VStack(alignment: .leading, spacing: 16) {
                    // Instrument selector
                    instrumentSelector
                    
                    // Chart
                    chartView(for: selected)
                        .frame(height: 300)
                    
                    // Stats
                    statsView(for: selected)
                }
            } else if !viewModel.marketData.isEmpty {
                VStack(spacing: 12) {
                    Text("Select an instrument to view chart")
                        .font(.subheadline)
                        .foregroundColor(themeManager.textSoftColor)
                    
                    instrumentSelector
                }
            }
        }
        .onAppear {
            Task {
                // Fetch more days of data to support all timeframes
                await viewModel.refresh(limit: 20, days: 365)
            }
        }
    }
    
    private var instrumentSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.marketData.prefix(10)) { instrument in
                    Button {
                        viewModel.selectInstrument(instrument)
                    } label: {
                        VStack(spacing: 4) {
                            Text(instrument.ticker)
                                .font(.system(size: 12, weight: .semibold))
                            if let change = instrument.priceChangePercent {
                                Text(String(format: "%.2f%%", change))
                                    .font(.system(size: 10))
                                    .foregroundColor(change >= 0 ? .green : .red)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.selectedInstrument?.id == instrument.id
                                ? themeManager.accentColor.opacity(0.2)
                                : themeManager.panelBackground
                        )
                        .foregroundColor(
                            viewModel.selectedInstrument?.id == instrument.id
                                ? themeManager.accentColor
                                : themeManager.textColor
                        )
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    viewModel.selectedInstrument?.id == instrument.id
                                        ? themeManager.accentColor
                                        : Color.clear,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    @ViewBuilder
    private func chartView(for instrument: InstrumentMarketData) -> some View {
        // Filter data by selected timeframe
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -selectedTimeframe.days, to: Date()) ?? Date()
        let filteredData = instrument.dataPoints.filter { $0.priceDate >= cutoffDate }
        
        switch chartType {
        case .line:
            lineChart(data: filteredData)
        case .area:
            areaChart(data: filteredData)
        case .candlestick:
            candlestickChart(data: filteredData)
        }
    }
    
    private func lineChart(data: [PriceDataPoint]) -> some View {
        let sortedData = data.sorted(by: { $0.priceDate < $1.priceDate })
        let yScale = calculateYScale(data: data)
        let strideCount = calculateStrideCount(dayCount: data.count)
        
        return Chart(sortedData, id: \.id) { point in
            LineMark(
                x: .value("Date", point.priceDate),
                y: .value("Price", point.close ?? 0)
            )
            .foregroundStyle(themeManager.accentColor)
            .interpolationMethod(.monotone)
        }
        .chartXAxis {
            xAxisMarks(strideCount: strideCount)
        }
        .chartYAxis {
            yAxisMarks()
        }
        .chartYScale(domain: yScale)
        .chartBackground { chartProxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(themeManager.panelBackground.opacity(0.3))
            }
        }
    }
    
    private func calculateYScale(data: [PriceDataPoint]) -> ClosedRange<Double> {
        let prices = data.compactMap { $0.close }
        let minPrice = prices.min() ?? 0
        let maxPrice = prices.max() ?? 0
        let padding = (maxPrice - minPrice) * 0.1 // 10% padding
        return max(0, minPrice - padding)...(maxPrice + padding)
    }
    
    private func calculateStrideCount(dayCount: Int) -> Int {
        if dayCount <= 7 {
            return 1
        } else if dayCount <= 30 {
            return 3
        } else if dayCount <= 90 {
            return 7
        } else if dayCount <= 180 {
            return 14
        } else {
            return 30
        }
    }
    
    private func xAxisMarks(strideCount: Int) -> some AxisContent {
        AxisMarks(values: .stride(by: .day, count: strideCount)) { value in
            AxisGridLine()
            AxisValueLabel(format: .dateTime.month().day(), centered: true)
        }
    }
    
    private func yAxisMarks() -> some AxisContent {
        AxisMarks { value in
            AxisGridLine()
            AxisValueLabel()
        }
    }
    
    private func areaChart(data: [PriceDataPoint]) -> some View {
        let sortedData = data.sorted(by: { $0.priceDate < $1.priceDate })
        let yScale = calculateYScale(data: data)
        let strideCount = calculateStrideCount(dayCount: data.count)
        let gradient = areaGradient
        
        return Chart(sortedData, id: \.id) { point in
            AreaMark(
                x: .value("Date", point.priceDate),
                y: .value("Price", point.close ?? 0)
            )
            .foregroundStyle(gradient)
            .interpolationMethod(.monotone)
        }
        .chartXAxis {
            xAxisMarks(strideCount: strideCount)
        }
        .chartYAxis {
            yAxisMarks()
        }
        .chartYScale(domain: yScale)
    }
    
    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [
                themeManager.accentColor.opacity(0.6),
                themeManager.accentColor.opacity(0.1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private func candlestickChart(data: [PriceDataPoint]) -> some View {
        let sortedData = data.sorted(by: { $0.priceDate < $1.priceDate })
        let yScale = calculateCandlestickYScale(data: data)
        let strideCount = calculateStrideCount(dayCount: data.count)
        
        return Chart(sortedData, id: \.id) { point in
            if let open = point.open,
               let high = point.high,
               let low = point.low,
               let close = point.close {
                candlestickMarks(
                    date: point.priceDate,
                    open: open,
                    high: high,
                    low: low,
                    close: close
                )
            }
        }
        .chartXAxis {
            xAxisMarks(strideCount: strideCount)
        }
        .chartYAxis {
            yAxisMarks()
        }
        .chartYScale(domain: yScale)
    }
    
    private func calculateCandlestickYScale(data: [PriceDataPoint]) -> ClosedRange<Double> {
        let highs = data.compactMap { $0.high }
        let lows = data.compactMap { $0.low }
        let minPrice = lows.min() ?? 0
        let maxPrice = highs.max() ?? 0
        let padding = (maxPrice - minPrice) * 0.1 // 10% padding
        return max(0, minPrice - padding)...(maxPrice + padding)
    }
    
    @ChartContentBuilder
    private func candlestickMarks(date: Date, open: Double, high: Double, low: Double, close: Double) -> some ChartContent {
        let color: Color = close >= open ? .green : .red
        
        RectangleMark(
            x: .value("Date", date),
            yStart: .value("Low", low),
            yEnd: .value("High", high),
            width: .fixed(4)
        )
        .foregroundStyle(color)
        
        RectangleMark(
            x: .value("Date", date),
            yStart: .value("Open", open),
            yEnd: .value("Close", close),
            width: .fixed(8)
        )
        .foregroundStyle(color)
    }
    
    private func statsView(for instrument: InstrumentMarketData) -> some View {
        HStack(spacing: 24) {
            if let latest = instrument.latestClose {
                statItem(label: "Latest", value: String(format: "$%.2f", latest))
            }
            if let change = instrument.priceChangePercent {
                statItem(
                    label: "Change",
                    value: String(format: "%.2f%%", change),
                    color: change >= 0 ? .green : .red
                )
            }
            if let avgVolume = instrument.averageVolume {
                statItem(label: "Avg Volume", value: formatVolume(avgVolume))
            }
        }
    }
    
    private func statItem(label: String, value: String, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(themeManager.textSoftColor)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color ?? themeManager.textColor)
        }
    }
    
    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1_000_000_000 {
            return String(format: "%.2fB", volume / 1_000_000_000)
        } else if volume >= 1_000_000 {
            return String(format: "%.2fM", volume / 1_000_000)
        } else if volume >= 1_000 {
            return String(format: "%.2fK", volume / 1_000)
        } else {
            return String(format: "%.0f", volume)
        }
    }
}

