pragma ComponentBehavior: Bound

import QtQuick

BarText {
    id: icon
    required property string fontFamily
    font {
        family: icon.fontFamily
        // Fit wide glyphs into the same maximum 12px artwork size as tray icons.
        pixelSize: Math.floor(12 * Math.min(1, 12 / Math.max(1,
            nominalMetrics.tightBoundingRect.width, nominalMetrics.tightBoundingRect.height)))
    }

    TextMetrics {
        id: nominalMetrics
        font { family: icon.fontFamily; pixelSize: 12 }
        text: icon.text
        renderType: Text.NativeRendering
    }
}
