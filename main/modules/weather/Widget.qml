import QtQuick
import Quickshell
import "../../components"
import "../.."
import "WeatherModel.js" as Model
import "."
BarModule {
    id: root
    active: popup.visible
    readonly property var current: Model.openMeteoCurrentCondition(WeatherService.report)
    implicitWidth: button.implicitWidth
    BarButton {
        id: button
        anchors.fill: parent
        text: Model.currentIcon(root.current, "󰖐") + (root.current ? " " + root.current.temp_C + "°" : "")
        tooltip: WeatherService.location ? WeatherService.location.name + " · weather" : "Weather · choose a city"
        onClicked: { popup.visible = !popup.visible; }
    }
    PopupWindow {
        id: popup
        anchor.item: button
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 8
        implicitWidth: 360
        implicitHeight: content.implicitHeight + 32
        color: "transparent"
        grabFocus: true
        onVisibleChanged: if (visible) Qt.callLater(() => panel.forceActiveFocus())
        Rectangle {
            id: panel
            anchors.fill: parent
            color: Theme.base
            border.color: Theme.surface1
            radius: Theme.panelRadius
            focus: true
            Keys.onEscapePressed: popup.visible = false
            Column {
                id: content
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: Theme.panelPadding }
                spacing: 14
                Text { text: WeatherService.location ? WeatherService.location.name : "Weather"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontLarge; font.bold: true }
                Row {
                    spacing: 12
                    visible: !!root.current
                    Text { anchors.verticalCenter: parent.verticalCenter; text: Model.currentIcon(root.current, "") ; color: Theme.blue; font.family: Theme.fontFamily; font.pixelSize: Theme.fontWeatherIcon }
                    Column {
                        spacing: 4
                        Text { text: root.current ? root.current.temp_C + "°C" : ""; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontHero }
                        Text { text: root.current ? "Feels like " + root.current.FeelsLikeC + "° · humidity " + root.current.humidity + "%" : ""; color: Theme.subtext0; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption }
                        Text { text: root.current ? "Wind " + root.current.windspeedKmph + " km/h" : ""; color: Theme.subtext0; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption }
                    }
                }
                Repeater {
                    model: Model.openMeteoForecastDays(WeatherService.report, Qt.formatDate(new Date(), "yyyy-MM-dd"))
                    Row {
                        required property var modelData
                        width: content.width
                        height: 24
                        Text { height: parent.height; verticalAlignment: Text.AlignVCenter; width: 145; text: Model.dayName(modelData.date); color: Theme.subtext0; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
                        Text { height: parent.height; verticalAlignment: Text.AlignVCenter; width: 45; text: Model.dayIcon(modelData); color: Theme.blue; font.family: Theme.fontFamily; font.pixelSize: Theme.fontLarge }
                        Text { height: parent.height; verticalAlignment: Text.AlignVCenter; text: modelData.mintempC + "° / " + modelData.maxtempC + "°"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
                    }
                }
                Text { width: parent.width; visible: !!WeatherService.error; text: WeatherService.error + (root.current ? " · showing saved forecast" : ""); color: Theme.peach; wrapMode: Text.Wrap; font.family: Theme.fontFamily; font.pixelSize: 11 }
                InputField {
                    id: city
                    width: parent.width
                    placeholderText: "City name, then Enter"
                    Accessible.name: "Weather city"
                    onAccepted: WeatherService.search(text)
                }
                Repeater {
                    model: WeatherService.suggestions
                    Rectangle {
                        required property var modelData
                        width: content.width; height: 42; radius: 5
                        color: choiceMouse.containsMouse ? Theme.surface0 : "transparent"
                        Column {
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 8 }
                            Text { width: parent.width; text: modelData.name; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; elide: Text.ElideRight }
                            Text { width: parent.width; text: [modelData.admin1, modelData.country].filter(Boolean).join(", "); color: Theme.overlay0; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption; elide: Text.ElideRight }
                        }
                        MouseArea { id: choiceMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: WeatherService.selectLocation(modelData) }
                    }
                }
                Row {
                    spacing: 12
                    Text { text: WeatherService.busy ? "Loading…" : "Refresh"; color: Theme.blue; font.family: Theme.fontFamily; font.pixelSize: 11; MouseArea { anchors.fill: parent; enabled: !WeatherService.busy; cursorShape: Qt.PointingHandCursor; onClicked: WeatherService.refresh() } }
                    Text { text: WeatherService.updated ? "Updated " + Qt.formatDateTime(new Date(WeatherService.updated), "ddd HH:mm") : "Choose a city above"; color: Theme.overlay0; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption }
                }
                Text { text: "Weather by Open-Meteo"; color: Theme.overlay0; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Qt.openUrlExternally("https://open-meteo.com/") } }
            }
        }
    }
}
