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
        }
    }
    
    var defaultColumnSpan: Int {
        switch self {
        case .marketStatus, .accountBalances:
            return 1
        case .positions, .watchList:
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
        WidgetConfig(id: "2", type: .accountBalances, columnSpan: 1, order: 1)
    ]
    @State private var showAddMenu = false
    @State private var draggedWidgetId: String? = nil
    @State private var hoveredWidgetId: String? = nil
    @State private var dropBeforeOrder: Int? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var widgetFrames: [String: CGRect] = [:]
    
    private let columns = 3
    private let columnSpacing: CGFloat = 20
    
    var body: some View {
        ScrollView {
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
                WidgetGridLayout(
                    columns: columns,
                    spacing: columnSpacing,
                    widgets: widgets.sorted { $0.order < $1.order },
                    draggedWidgetId: draggedWidgetId,
                    dropBeforeOrder: dropBeforeOrder
                ) { widget in
                    widgetCard(for: widget)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .coordinateSpace(name: "widgetGrid")
        .onPreferenceChange(WidgetFramePreferenceKey.self) { frames in
            widgetFrames = frames
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
        let isHovered = hoveredWidgetId == config.id
        let isDragged = draggedWidgetId == config.id
        let showDropBefore = dropBeforeOrder == config.order && draggedWidgetId != nil && draggedWidgetId != config.id
        
        return VStack(spacing: 0) {
            // Drop indicator before widget
            if showDropBefore {
                Rectangle()
                    .fill(themeManager.accentColor)
                    .frame(height: 3)
                    .padding(.vertical, 4)
            }
            
            // Widget content
            Group {
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
                }
            }
            .opacity(isDragged ? 0.4 : 1.0)
            .overlay(
                // Controls overlay - only show on hover
                Group {
                    if isHovered && !isDragged {
                        VStack {
                            HStack {
                                Spacer()
                                
                                // Controls (top-right) - compact layout
                                HStack(spacing: 4) {
                                    resizeControls(for: config)
                                    removeButton(for: config)
                                }
                            }
                            .padding(6)
                            
                            Spacer()
                        }
                    }
                },
                alignment: .topTrailing
            )
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: WidgetFramePreferenceKey.self, value: [
                            config.id: geometry.frame(in: .named("widgetGrid"))
                        ])
                }
            )
            .offset(isDragged ? dragOffset : .zero)
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        if draggedWidgetId == nil {
                            draggedWidgetId = config.id
                        }
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        if let draggedId = draggedWidgetId {
                            if let targetOrder = dropBeforeOrder {
                                handleDrop(draggedId: draggedId, targetOrder: targetOrder)
                            }
                        }
                        draggedWidgetId = nil
                        dragOffset = .zero
                        dropBeforeOrder = nil
                    }
            )
            .onHover { hovering in
                if !isDragged {
                    hoveredWidgetId = hovering ? config.id : nil
                }
            }
        }
        .background(
            // Drop zone - detects when dragging over this widget
            Group {
                if draggedWidgetId != nil && draggedWidgetId != config.id {
                    Color.clear
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            if hovering {
                                dropBeforeOrder = config.order
                            } else if dropBeforeOrder == config.order {
                                dropBeforeOrder = nil
                            }
                        }
                }
            }
        )
        .zIndex(isDragged ? 1000 : 0)
    }
    
    private func resizeControls(for config: WidgetConfig) -> some View {
        HStack(spacing: 4) {
            ForEach([1, 2, 3], id: \.self) { span in
                resizeButton(span: span, currentSpan: config.columnSpan, config: config)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(themeManager.panelBackground.opacity(0.9))
        .cornerRadius(6)
    }
    
    private func resizeButton(span: Int, currentSpan: Int, config: WidgetConfig) -> some View {
        Button {
            resizeWidget(id: config.id, newSpan: span)
        } label: {
            Text("\(span)")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(
                    currentSpan == span
                        ? themeManager.accentColor
                        : themeManager.textSoftColor
                )
                .frame(width: 18, height: 18)
                .background(
                    currentSpan == span
                        ? themeManager.accentColor.opacity(0.2)
                        : Color.clear
                )
                .cornerRadius(3)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(
                            currentSpan == span
                                ? themeManager.accentColor
                                : Color.clear,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .help("Resize to \(span) column\(span == 1 ? "" : "s")")
    }
    
    private func removeButton(for config: WidgetConfig) -> some View {
        Button {
            removeWidget(id: config.id)
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(themeManager.textSoftColor)
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Remove widget")
    }
    
    private func addWidget(type: WidgetType) {
        let newOrder = widgets.isEmpty ? 0 : (widgets.map { $0.order }.max() ?? 0) + 1
        let newId = "widget-\(Date().timeIntervalSince1970)-\(UUID().uuidString.prefix(8))"
        widgets.append(WidgetConfig(id: newId, type: type, columnSpan: type.defaultColumnSpan, order: newOrder))
    }
    
    private func removeWidget(id: String) {
        widgets.removeAll { $0.id == id }
    }
    
    private func resizeWidget(id: String, newSpan: Int) {
        guard newSpan >= 1 && newSpan <= 3 else { return }
        if let index = widgets.firstIndex(where: { $0.id == id }) {
            widgets[index].columnSpan = newSpan
        }
    }
    
    
    private func handleDrop(draggedId: String, targetOrder: Int) {
        guard let sourceIndex = widgets.firstIndex(where: { $0.id == draggedId }),
              let targetIndex = widgets.firstIndex(where: { $0.order == targetOrder }),
              sourceIndex != targetIndex else {
            return
        }
        
        let draggedWidget = widgets[sourceIndex]
        
        // Remove from source
        widgets.remove(at: sourceIndex)
        
        // Calculate new target index after removal
        let adjustedTargetIndex = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        
        // Insert at target position
        widgets.insert(draggedWidget, at: adjustedTargetIndex)
        
        // Reorder all widgets
        for (index, _) in widgets.enumerated() {
            widgets[index].order = index
        }
    }
}

// MARK: - Widget Frame Preference Key

struct WidgetFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

// MARK: - Widget Grid Layout

struct WidgetGridLayout<Content: View>: View {
    let columns: Int
    let spacing: CGFloat
    let widgets: [WidgetConfig]
    let draggedWidgetId: String?
    let dropBeforeOrder: Int?
    let content: (WidgetConfig) -> Content
    
    var body: some View {
        GeometryReader { geometry in
            let columnWidth = (geometry.size.width - (spacing * CGFloat(columns - 1))) / CGFloat(columns)
            
            VStack(alignment: .leading, spacing: spacing) {
                ForEach(Array(widgetRows(columnWidth: columnWidth, totalWidth: geometry.size.width).enumerated()), id: \.offset) { rowIndex, rowWidgets in
                    HStack(alignment: .top, spacing: spacing) {
                        ForEach(rowWidgets) { widget in
                            content(widget)
                                .frame(width: columnWidth * CGFloat(widget.columnSpan) + spacing * CGFloat(widget.columnSpan - 1))
                        }
                        
                        Spacer(minLength: 0)
                    }
                }
            }
            .coordinateSpace(name: "widgetGrid")
        }
    }
    
    private func widgetRows(columnWidth: CGFloat, totalWidth: CGFloat) -> [[WidgetConfig]] {
        var currentRow: [WidgetConfig] = []
        var currentRowWidth: CGFloat = 0
        var rows: [[WidgetConfig]] = []
        
        // Group widgets into rows
        for widget in widgets {
            let widgetWidth = columnWidth * CGFloat(widget.columnSpan) + spacing * CGFloat(widget.columnSpan - 1)
            
            if currentRowWidth + widgetWidth + (currentRow.isEmpty ? 0 : spacing) > totalWidth && !currentRow.isEmpty {
                rows.append(currentRow)
                currentRow = [widget]
                currentRowWidth = widgetWidth
            } else {
                currentRow.append(widget)
                currentRowWidth += widgetWidth + (currentRow.count > 1 ? spacing : 0)
            }
        }
        
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        
        return rows
    }
}
