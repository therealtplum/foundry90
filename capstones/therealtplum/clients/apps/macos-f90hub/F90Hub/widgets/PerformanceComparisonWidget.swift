//
//  PerformanceComparisonWidget.swift
//  FMHubControl
//
//  Performance comparison widget showing multiple instruments side-by-side
//

import SwiftUI
import Charts
import F90Shared

struct PerformanceComparisonWidget: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel = MarketDataViewModel()
    @State private var selectedInstruments: Set<Int64> = []
    @State private var comparisonType: ComparisonType = .priceChange
    
    enum ComparisonType: String, CaseIterable {
        case priceChange = "Price Change %"
        case absolutePrice = "Absolute Price"
        case volume = "Volume"
    }
    
    var body: some View {
        BaseWidgetView(
            title: "Performance Comparison",
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            actions: AnyView(
                HStack(spacing: 8) {
                    Picker("", selection: $comparisonType) {
                        ForEach(ComparisonType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                    
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
            if !viewModel.marketData.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    // Instrument selector (multi-select)
                    instrumentSelector
                    
                    // Comparison chart
                    if !selectedInstruments.isEmpty {
                        comparisonChart
                            .frame(height: 300)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 32))
                                .foregroundColor(themeManager.textSoftColor)
                            Text("Select instruments to compare")
                                .font(.subheadline)
                                .foregroundColor(themeManager.textSoftColor)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                    }
                    
                    // Summary stats
                    if !selectedInstruments.isEmpty {
                        comparisonStats
                    }
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.refresh()
            }
            // Auto-select top 3 instruments
            if selectedInstruments.isEmpty {
                selectedInstruments = Set(viewModel.marketData.prefix(3).map { $0.id })
            }
        }
    }
    
    private var instrumentSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.marketData.prefix(15)) { instrument in
                    Button {
                        if selectedInstruments.contains(instrument.id) {
                            selectedInstruments.remove(instrument.id)
                        } else {
                            selectedInstruments.insert(instrument.id)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: selectedInstruments.contains(instrument.id) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 12))
                            
                            Text(instrument.ticker)
                                .font(.system(size: 12, weight: .medium))
                            
                            if let change = instrument.priceChangePercent {
                                Text(String(format: "%.1f%%", change))
                                    .font(.system(size: 10))
                                    .foregroundColor(change >= 0 ? .green : .red)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selectedInstruments.contains(instrument.id)
                                ? themeManager.accentColor.opacity(0.2)
                                : themeManager.panelBackground
                        )
                        .foregroundColor(
                            selectedInstruments.contains(instrument.id)
                                ? themeManager.accentColor
                                : themeManager.textColor
                        )
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    selectedInstruments.contains(instrument.id)
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
    
    private var comparisonChart: some View {
        let selectedData = viewModel.marketData.filter { selectedInstruments.contains($0.id) }
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .cyan, .yellow, .mint]
        
        return Group {
            switch comparisonType {
            case .priceChange:
                priceChangeChart(data: selectedData, colors: colors)
            case .absolutePrice:
                absolutePriceChart(data: selectedData, colors: colors)
            case .volume:
                volumeComparisonChart(data: selectedData, colors: colors)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month().day())
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartLegend {
            HStack(spacing: 16) {
                ForEach(Array(selectedData.enumerated()), id: \.element.id) { index, instrument in
                    let color = colors[index % colors.count]
                    HStack(spacing: 4) {
                        Circle()
                            .fill(color)
                            .frame(width: 8, height: 8)
                        Text(instrument.ticker)
                            .font(.caption)
                            .foregroundColor(themeManager.textColor)
                    }
                }
            }
        }
    }
    
    private func priceChangeChart(data: [InstrumentMarketData], colors: [Color]) -> some View {
        Chart {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, instrument in
                let sortedData = instrument.dataPoints.sorted(by: { $0.priceDate < $1.priceDate })
                if let firstClose = sortedData.first?.close, firstClose > 0 {
                    ForEach(sortedData, id: \.id) { point in
                        if let currentClose = point.close {
                            let changePercent = ((currentClose - firstClose) / firstClose) * 100.0
                            LineMark(
                                x: .value("Date", point.priceDate),
                                y: .value("Change %", changePercent)
                            )
                            .foregroundStyle(colors[index % colors.count])
                            .interpolationMethod(.monotone)
                        }
                    }
                }
            }
        }
        .chartXAxis {
            let allDates = data.flatMap { $0.dataPoints.map { $0.priceDate } }
            let dayCount = Set(allDates).count
            let strideCount = calculateStrideCount(dayCount: dayCount)
            
            AxisMarks(values: .stride(by: .day, count: strideCount)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month().day(), centered: true)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartLegend {
            chartLegend(data: data, colors: colors)
        }
    }
    
    private func absolutePriceChart(data: [InstrumentMarketData], colors: [Color]) -> some View {
        return Chart {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, instrument in
                ForEach(instrument.dataPoints.sorted(by: { $0.priceDate < $1.priceDate }), id: \.id) { point in
                    if let close = point.close {
                        LineMark(
                            x: .value("Date", point.priceDate),
                            y: .value("Price", close)
                        )
                        .foregroundStyle(colors[index % colors.count])
                        .interpolationMethod(.monotone)
                    }
                }
            }
        }
        .chartXAxis {
            let allDates = data.flatMap { $0.dataPoints.map { $0.priceDate } }
            let dayCount = Set(allDates).count
            let strideCount = calculateStrideCount(dayCount: dayCount)
            
            AxisMarks(values: .stride(by: .day, count: strideCount)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month().day(), centered: true)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartLegend {
            chartLegend(data: data, colors: colors)
        }
    }
    
    private func volumeComparisonChart(data: [InstrumentMarketData], colors: [Color]) -> some View {
        return Chart {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, instrument in
                ForEach(instrument.dataPoints.sorted(by: { $0.priceDate < $1.priceDate }), id: \.id) { point in
                    if let volume = point.volume {
                        BarMark(
                            x: .value("Date", point.priceDate),
                            y: .value("Volume", volume)
                        )
                        .foregroundStyle(colors[index % colors.count].opacity(0.6))
                    }
                }
            }
        }
        .chartXAxis {
            let allDates = data.flatMap { $0.dataPoints.map { $0.priceDate } }
            let dayCount = Set(allDates).count
            let strideCount = calculateStrideCount(dayCount: dayCount)
            
            AxisMarks(values: .stride(by: .day, count: strideCount)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month().day(), centered: true)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartLegend {
            chartLegend(data: data, colors: colors)
        }
    }
    
    private func xAxisMarks(data: [InstrumentMarketData]) -> some AxisContent {
        let allDates = data.flatMap { $0.dataPoints.map { $0.priceDate } }
        let dayCount = Set(allDates).count
        let strideCount = calculateStrideCount(dayCount: dayCount)
        
        return AxisMarks(values: .stride(by: .day, count: strideCount)) { value in
            AxisGridLine()
            AxisValueLabel(format: .dateTime.month().day(), centered: true)
        }
    }
    
    private func yAxisMarks() -> some AxisContent {
        return AxisMarks { value in
            AxisGridLine()
            AxisValueLabel()
        }
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
    
    private func chartLegend(data: [InstrumentMarketData], colors: [Color]) -> some View {
        HStack(spacing: 16) {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, instrument in
                let color = colors[index % colors.count]
                HStack(spacing: 4) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text(instrument.ticker)
                        .font(.caption)
                        .foregroundColor(themeManager.textColor)
                }
            }
        }
    }
    
    private var comparisonStats: some View {
        let selectedData = viewModel.marketData.filter { selectedInstruments.contains($0.id) }
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)
                .foregroundColor(themeManager.textColor)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(selectedData) { instrument in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(instrument.ticker)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(themeManager.textColor)
                        
                        if let latest = instrument.latestClose {
                            Text(String(format: "$%.2f", latest))
                                .font(.subheadline)
                                .foregroundColor(themeManager.textSoftColor)
                        }
                        
                        if let change = instrument.priceChangePercent {
                            HStack(spacing: 4) {
                                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 10))
                                Text(String(format: "%.2f%%", change))
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(change >= 0 ? .green : .red)
                        }
                    }
                    .padding(12)
                    .background(themeManager.panelBackground)
                    .cornerRadius(8)
                }
            }
        }
    }
}

