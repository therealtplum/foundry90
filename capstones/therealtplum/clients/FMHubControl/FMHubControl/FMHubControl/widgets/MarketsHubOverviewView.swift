//
//  MarketsHubOverviewView.swift
//  FMHubControl
//
//  Overview tab with modular widget grid system supporting drag-and-drop and resizing
//

import SwiftUI

enum WidgetType: String, CaseIterable, Identifiable {
    case marketStatus = "Market Status"
    case accountBalances = "Account Balances"
    case positions = "Positions"
    case watchList = "Watch List"
    case fredReleases = "Economic Releases"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .marketStatus:
            return "chart.line.uptrend.xyaxis"
        case .accountBalances:
            return "dollarsign.circle"
        case .positions:
            return "briefcase"
        case .watchList:
            return "list.bullet"
        case .fredReleases:
            return "calendar.badge.clock"
        }
    }
    
    var defaultColumnSpan: Int {
        switch self {
        case .marketStatus, .accountBalances:
            return 1
        case .positions, .watchList, .fredReleases:
            return 2
        }
    }
}

struct WidgetConfig: Identifiable, Equatable {
    let id: String
    let type: WidgetType
    var columnSpan: Int // 1, 2, or 3 columns
    var order: Int // Display order
    
    init(id: String, type: WidgetType, columnSpan: Int? = nil, order: Int = 0) {
        self.id = id
        self.type = type
        self.columnSpan = min(3, max(1, columnSpan ?? type.defaultColumnSpan))
        self.order = order
    }
}

struct MarketsHubOverviewView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var widgets: [WidgetConfig] = [
        WidgetConfig(id: "1", type: .marketStatus, columnSpan: 1, order: 0),
        WidgetConfig(id: "2", type: .accountBalances, columnSpan: 1, order: 1),
        WidgetConfig(id: "3", type: .fredReleases, columnSpan: 2, order: 2)
    ]
    @State private var showAddMenu = false
    @State private var editingWidgetId: String? = nil
    
    private let columns = 3
    private let columnSpacing: CGFloat = 20
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Controls
            HStack {
                Spacer()
                
                Button {
                    showAddMenu.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 14))
                        Text("Add Widget")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(themeManager.accentColor.opacity(0.2))
                    .foregroundColor(themeManager.accentColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeManager.accentColor, lineWidth: 1)
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(availableWidgets.isEmpty)
                .popover(isPresented: $showAddMenu) {
                    addMenuView
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            // Widget Grid - 3 column layout
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: columnSpacing),
                    GridItem(.flexible(), spacing: columnSpacing),
                    GridItem(.flexible(), spacing: columnSpacing)
                ], alignment: .leading, spacing: columnSpacing) {
                    ForEach(widgets.sorted { $0.order < $1.order }) { widget in
                        widgetCard(for: widget)
                            .gridCellColumns(widget.columnSpan)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
    
    private var availableWidgets: [WidgetType] {
        let usedTypes = Set(widgets.map { $0.type })
        return WidgetType.allCases.filter { !usedTypes.contains($0) }
    }
    
    private var addMenuView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(availableWidgets) { widgetType in
                Button {
                    addWidget(type: widgetType)
                    showAddMenu = false
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: widgetType.icon)
                            .font(.system(size: 14))
                            .frame(width: 20)
                        Text(widgetType.rawValue)
                            .font(.system(size: 14))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(themeManager.textColor)
                }
                .buttonStyle(.plain)
                .background(
                    Rectangle()
                        .fill(themeManager.panelBackground)
                )
                
                if widgetType != availableWidgets.last {
                    Divider()
                        .background(themeManager.panelBorder)
                }
            }
        }
        .frame(width: 200)
        .background(themeManager.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(themeManager.panelBorder, lineWidth: 1)
        )
        .cornerRadius(8)
        .padding(8)
    }
    
    private func widgetCard(for config: WidgetConfig) -> some View {
        let isEditing = editingWidgetId == config.id
        let sortedWidgets = widgets.sorted { $0.order < $1.order }
        let currentIndex = sortedWidgets.firstIndex(where: { $0.id == config.id }) ?? 0
        let canMoveUp = currentIndex > 0
        let canMoveDown = currentIndex < sortedWidgets.count - 1
        
        return Group {
            switch config.type {
            case .marketStatus:
                MarketStatusWidget()
            case .accountBalances:
                AccountBalancesWidget()
            case .positions:
                Text("Positions Widget")
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .padding()
                    .background(themeManager.panelBackground)
                    .cornerRadius(12)
            case .watchList:
                Text("Watch List Widget")
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .padding()
                    .background(themeManager.panelBackground)
                    .cornerRadius(12)
            case .fredReleases:
                FredReleasesWidget()
            }
        }
        .overlay(
            // Edit controls overlay
            Group {
                if isEditing {
                    VStack {
                        HStack {
                            Spacer()
                            
                            // Controls (top-right, offset below header)
                            VStack(spacing: 8) {
                                // Column span controls
                                HStack(spacing: 4) {
                                    ForEach([1, 2, 3], id: \.self) { span in
                                        Button {
                                            updateColumnSpan(id: config.id, span: span)
                                        } label: {
                                            Text("\(span)")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundColor(
                                                    config.columnSpan == span
                                                        ? themeManager.accentColor
                                                        : themeManager.textSoftColor
                                                )
                                                .frame(width: 24, height: 24)
                                                .background(
                                                    config.columnSpan == span
                                                        ? themeManager.accentColor.opacity(0.2)
                                                        : themeManager.panelBackground.opacity(0.8)
                                                )
                                                .cornerRadius(4)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                
                                // Reorder buttons
                                HStack(spacing: 4) {
                                    Button {
                                        moveWidgetUp(id: config.id)
                                    } label: {
                                        Image(systemName: "arrow.up")
                                            .font(.system(size: 10))
                                            .foregroundColor(canMoveUp ? themeManager.textColor : themeManager.textSoftColor)
                                            .frame(width: 24, height: 24)
                                            .background(themeManager.panelBackground.opacity(0.8))
                                            .cornerRadius(4)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!canMoveUp)
                                    
                                    Button {
                                        moveWidgetDown(id: config.id)
                                    } label: {
                                        Image(systemName: "arrow.down")
                                            .font(.system(size: 10))
                                            .foregroundColor(canMoveDown ? themeManager.textColor : themeManager.textSoftColor)
                                            .frame(width: 24, height: 24)
                                            .background(themeManager.panelBackground.opacity(0.8))
                                            .cornerRadius(4)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!canMoveDown)
                                    
                                    Button {
                                        removeWidget(id: config.id)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10))
                                            .foregroundColor(themeManager.statusDownColor)
                                            .frame(width: 24, height: 24)
                                            .background(themeManager.panelBackground.opacity(0.8))
                                            .cornerRadius(4)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(8)
                            .background(themeManager.panelBackground.opacity(0.95))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(themeManager.panelBorder, lineWidth: 1)
                            )
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 56) // Offset below header (header height ~48px + spacing)
                    .padding(.trailing, 8)
                } else {
                    // Edit button (ellipsis) - show on tap, positioned furthest to the right
                    VStack {
                        HStack {
                            Spacer()
                            
                            Button {
                                editingWidgetId = config.id
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 12))
                                    .foregroundColor(themeManager.textSoftColor)
                                    .frame(width: 28, height: 28)
                                    .background(themeManager.panelBackground.opacity(0.8))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 8)
                }
            },
            alignment: .topTrailing
        )
        .onTapGesture {
            // Close edit mode when tapping outside
            if isEditing {
                editingWidgetId = nil
            }
        }
    }
    
    private func addWidget(type: WidgetType) {
        let newOrder = widgets.isEmpty ? 0 : (widgets.map { $0.order }.max() ?? 0) + 1
        let newId = "widget-\(Date().timeIntervalSince1970)-\(UUID().uuidString.prefix(8))"
        widgets.append(WidgetConfig(id: newId, type: type, columnSpan: type.defaultColumnSpan, order: newOrder))
    }
    
    private func removeWidget(id: String) {
        widgets.removeAll { $0.id == id }
        if editingWidgetId == id {
            editingWidgetId = nil
        }
    }
    
    private func updateColumnSpan(id: String, span: Int) {
        guard span >= 1 && span <= 3 else { return }
        if let index = widgets.firstIndex(where: { $0.id == id }) {
            widgets[index].columnSpan = span
        }
    }
    
    private func moveWidgetUp(id: String) {
        guard let currentIndex = widgets.firstIndex(where: { $0.id == id }),
              currentIndex > 0 else { return }
        
        let previousIndex = currentIndex - 1
        let currentOrder = widgets[currentIndex].order
        let previousOrder = widgets[previousIndex].order
        
        widgets[currentIndex].order = previousOrder
        widgets[previousIndex].order = currentOrder
    }
    
    private func moveWidgetDown(id: String) {
        guard let currentIndex = widgets.firstIndex(where: { $0.id == id }),
              currentIndex < widgets.count - 1 else { return }
        
        let nextIndex = currentIndex + 1
        let currentOrder = widgets[currentIndex].order
        let nextOrder = widgets[nextIndex].order
        
        widgets[currentIndex].order = nextOrder
        widgets[nextIndex].order = currentOrder
    }
}

