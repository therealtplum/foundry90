//
//  VolumeChartWidget.swift
//  FMHubControl
//
//  Volume chart widget showing trading volume over time
//

import SwiftUI
import Charts
import F90Shared

struct VolumeChartWidget: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel = MarketDataViewModel()
    @State private var selectedTimeframe: Timeframe = .days30
    
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
    
    var body: some View {
        BaseWidgetView(
            title: "Volume Analysis",
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            actions: AnyView(headerActions)
        ) {
            chartContent
        }
        .onAppear {
            Task {
                // Fetch more days of data to support all timeframes
                await viewModel.refresh(limit: 20, days: 365)
            }
        }
    }
    
    @ViewBuilder
    private var chartContent: some View {
        if let selected = viewModel.selectedInstrument {
            // Filter data by selected timeframe
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -selectedTimeframe.days, to: Date()) ?? Date()
            let filteredData = selected.dataPoints
                .filter { $0.priceDate >= cutoffDate }
                .sorted(by: { $0.priceDate < $1.priceDate })
            
            VStack(alignment: .leading, spacing: 16) {
                instrumentHeader(for: selected)
                volumeChart(data: filteredData)
                volumeStats(data: filteredData)
            }
        } else if !viewModel.marketData.isEmpty {
            VStack(spacing: 12) {
                Text("Select an instrument to view volume")
                    .font(.subheadline)
                    .foregroundColor(themeManager.textSoftColor)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.marketData.prefix(15)) { instrument in
                            Button {
                                viewModel.selectInstrument(instrument)
                            } label: {
                                VStack(spacing: 4) {
                                    Text(instrument.ticker)
                                        .font(.system(size: 12, weight: .semibold))
                                    if let change = instrument.priceChangePercent {
                                        Text(String(format: "%.1f%%", change))
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
        }
    }
    
    private func instrumentHeader(for instrument: InstrumentMarketData) -> some View {
        HStack {
            Text(instrument.ticker)
                .font(.system(size: 18, weight: .semibold))
            Text(instrument.name)
                .font(.subheadline)
                .foregroundColor(themeManager.textSoftColor)
            Spacer()
        }
    }
    
    private func volumeChart(data: [PriceDataPoint]) -> some View {
        Chart(data, id: \.id) { point in
            BarMark(
                x: .value("Date", point.priceDate),
                y: .value("Volume", point.volume ?? 0)
            )
            .foregroundStyle(volumeGradient)
        }
        .frame(height: 250)
        .chartXAxis {
            xAxisMarks(dayCount: data.count)
        }
        .chartYAxis {
            yAxisMarks
        }
        .chartYScale(domain: 0...(data.compactMap { $0.volume }.max() ?? 0) * 1.1)
    }
    
    private var volumeGradient: LinearGradient {
        LinearGradient(
            colors: [
                themeManager.accentColor.opacity(0.8),
                themeManager.accentColor.opacity(0.4)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private func xAxisMarks(dayCount: Int) -> some AxisContent {
        let strideCount: Int
        if dayCount <= 7 {
            strideCount = 1
        } else if dayCount <= 30 {
            strideCount = 3
        } else if dayCount <= 90 {
            strideCount = 7
        } else if dayCount <= 180 {
            strideCount = 14
        } else {
            strideCount = 30
        }
        
        return AxisMarks(values: .stride(by: .day, count: strideCount)) { value in
            AxisGridLine()
            AxisValueLabel(format: .dateTime.month().day(), centered: true)
        }
    }
    
    private var yAxisMarks: some AxisContent {
        AxisMarks { value in
            AxisGridLine()
            AxisValueLabel {
                if let intValue = value.as(Double.self) {
                    Text(formatVolume(intValue))
                        .font(.caption2)
                }
            }
        }
    }
    
    private func volumeStats(data: [PriceDataPoint]) -> some View {
        let avgVolume = data.compactMap { $0.volume }.reduce(0, +) / Double(max(1, data.count))
        let maxVolume = data.compactMap { $0.volume }.max()
        
        return Group {
            if let maxVolume = maxVolume {
                HStack(spacing: 24) {
                    statItem(label: "Average", value: formatVolume(avgVolume))
                    statItem(label: "Peak", value: formatVolume(maxVolume))
                    if let latest = data.last?.volume {
                        statItem(label: "Latest", value: formatVolume(latest))
                    }
                }
            }
        }
    }
    
    private var headerActions: some View {
        HStack(spacing: 8) {
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
            
            refreshButton
        }
        .padding(.trailing, 36)
    }
    
    private var refreshButton: some View {
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
    
    private func statItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(themeManager.textSoftColor)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(themeManager.textColor)
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

