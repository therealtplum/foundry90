// Markets Hub - Main dashboard page with modular widgets
"use client";

import { useState } from "react";
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
  DragEndEvent,
} from "@dnd-kit/core";
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
} from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { MarketsHubLayout } from "../../components/markets/MarketsHubLayout";
import { WatchListWidget } from "../../components/markets/widgets/WatchListWidget";
import { NewsWidget } from "../../components/markets/widgets/NewsWidget";
import { MarketInsightsWidget } from "../../components/markets/widgets/MarketInsightsWidget";
import { AccountBalancesWidget } from "../../components/markets/widgets/AccountBalancesWidget";
import { MarketOverviewWidget } from "../../components/markets/widgets/MarketOverviewWidget";
import { PositionsWidget } from "../../components/markets/widgets/PositionsWidget";
import { PriceChartWidget } from "../../components/markets/widgets/PriceChartWidget";

type WidgetType =
  | "watchlist"
  | "news"
  | "insights"
  | "balances"
  | "overview"
  | "positions"
  | "chart";

interface WidgetConfig {
  id: string;
  type: WidgetType;
}

const WIDGET_REGISTRY: Record<WidgetType, { title: string; component: React.ComponentType<any> }> = {
  watchlist: { title: "Watch List", component: WatchListWidget },
  news: { title: "Market News", component: NewsWidget },
  insights: { title: "Market Insights", component: MarketInsightsWidget },
  balances: { title: "Account Balances", component: AccountBalancesWidget },
  overview: { title: "Market Overview", component: MarketOverviewWidget },
  positions: { title: "Positions", component: PositionsWidget },
  chart: { title: "Price Chart", component: PriceChartWidget },
};

function SortableWidget({ id, type, onRemove }: { id: string; type: WidgetType; onRemove: (id: string) => void }) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.5 : 1,
  };

  const WidgetComponent = WIDGET_REGISTRY[type].component;

  return (
    <div ref={setNodeRef} style={style} className="markets-widget-sortable">
      <div className="markets-widget-drag-handle" {...attributes} {...listeners}>
        <span className="markets-widget-drag-icon">⋮⋮</span>
      </div>
      <button
        className="markets-widget-remove-btn"
        onClick={() => onRemove(id)}
        title="Remove widget"
        aria-label="Remove widget"
      >
        ×
      </button>
      <WidgetComponent />
    </div>
  );
}

export default function MarketsHubPage() {
  const [widgets, setWidgets] = useState<WidgetConfig[]>([
    { id: "1", type: "overview" as WidgetType },
    { id: "2", type: "watchlist" as WidgetType },
    { id: "3", type: "news" as WidgetType },
    { id: "4", type: "balances" as WidgetType },
    { id: "5", type: "positions" as WidgetType },
    { id: "6", type: "insights" as WidgetType },
    { id: "7", type: "chart" as WidgetType },
  ]);

  const [showAddMenu, setShowAddMenu] = useState(false);

  const sensors = useSensors(
    useSensor(PointerSensor),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  );

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event;

    if (over && active.id !== over.id) {
      setWidgets((items) => {
        const oldIndex = items.findIndex((item) => item.id === active.id);
        const newIndex = items.findIndex((item) => item.id === over.id);
        return arrayMove(items, oldIndex, newIndex);
      });
    }
  }

  function handleRemoveWidget(id: string) {
    setWidgets((items) => items.filter((item) => item.id !== id));
  }

  function handleAddWidget(type: WidgetType) {
    const newId = `widget-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    setWidgets((items) => [...items, { id: newId, type }]);
    setShowAddMenu(false);
  }

  const availableWidgets = Object.entries(WIDGET_REGISTRY).filter(
    ([type]) => !widgets.some((w) => w.type === type)
  );

  return (
    <MarketsHubLayout>
      <div className="markets-hub-controls">
        <button
          className="markets-hub-add-btn"
          onClick={() => setShowAddMenu(!showAddMenu)}
          disabled={availableWidgets.length === 0}
        >
          + Add Widget
        </button>
        {showAddMenu && availableWidgets.length > 0 && (
          <div className="markets-hub-add-menu">
            {availableWidgets.map(([type, { title }]) => (
              <button
                key={type}
                className="markets-hub-add-menu-item"
                onClick={() => handleAddWidget(type as WidgetType)}
              >
                {title}
              </button>
            ))}
          </div>
        )}
      </div>

      <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
        <SortableContext items={widgets.map((w) => w.id)}>
          <div className="markets-hub-grid">
            {widgets.map((widget) => (
              <div key={widget.id} className="markets-hub-widget-container">
                <SortableWidget id={widget.id} type={widget.type} onRemove={handleRemoveWidget} />
              </div>
            ))}
          </div>
        </SortableContext>
      </DndContext>
    </MarketsHubLayout>
  );
}
