pragma ComponentBehavior: Bound

import QtQuick

Item {
    property alias text: glyph.text
    property alias color: glyph.color
    property alias font: glyph.font
    width: Math.ceil(metrics.tightBoundingRect.width)
    height: Math.ceil(metrics.tightBoundingRect.height)

    TextMetrics {
        id: metrics
        font: glyph.font
        text: glyph.text
        renderType: Text.NativeRendering
    }

    Text {
        id: glyph
        // Size and position by visible ink, not font leading or side bearings.
        x: -metrics.tightBoundingRect.x
        y: -metrics.tightBoundingRect.y - baselineOffset
        font { family: "sans-serif"; pixelSize: 11 }
        renderType: Text.NativeRendering
    }
}
