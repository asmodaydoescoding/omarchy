import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property var providers: []
    property int providerIndex: 0
    property string lastError: ""
    property int refreshIntervalSec: Math.max(60, Number(Plasmoid.configuration.refreshIntervalSec || 900))
    property string usageCommand: "bash -c 'omarchy-agent-usage-update >/dev/null 2>&1; omarchy-agent-usage-list'"
    readonly property var provider: providers.length > 0 ? providers[Math.min(providerIndex, providers.length - 1)] : ({})

    Plasmoid.icon: "applications-science"
    toolTipMainText: providers.length > 0 ? String(provider.name || provider.id || "Agents") : "Agents"
    toolTipSubText: providers.length > 0 ? String(provider.plan || provider.status || "Usage") : "No AI usage recorded"

    function refresh() {
        if (!executable.connectedSources.includes(root.usageCommand))
            executable.connectSource(root.usageCommand)
    }

    function nextProvider() {
        if (providers.length > 0)
            providerIndex = (providerIndex + 1) % providers.length
    }

    function launchAgent() {
        executable.connectSource("omarchy-agent --pick")
    }

    function acceptData(source, data) {
        if (source === "omarchy-agent --pick") {
            executable.disconnectSource(source)
            return
        }
        try {
            var parsed = JSON.parse(String(data.stdout || "[]"))
            if (!Array.isArray(parsed))
                throw new Error("usage records are not an array")
            root.providers = parsed
            if (root.providerIndex >= parsed.length)
                root.providerIndex = 0
            root.lastError = ""
        } catch (error) {
            root.lastError = "Usage refresh failed"
        }
        executable.disconnectSource(source)
    }

    function valueOr(value, fallback) {
        return value === undefined || value === null || value === "" ? fallback : value
    }

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) { root.acceptData(source, data) }
    }

    Timer {
        interval: root.refreshIntervalSec * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
            if (root.providers.length > 0)
                root.providerIndex = (root.providerIndex + root.providers.length - 1) % root.providers.length
            event.accepted = true
        } else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
            root.nextProvider()
            event.accepted = true
        } else if (event.key === Qt.Key_R || event.key === Qt.Key_Return) {
            root.refresh()
            event.accepted = true
        }
    }

    compactRepresentation: Item {
        implicitWidth: Kirigami.Units.iconSizes.smallMedium
        implicitHeight: Kirigami.Units.iconSizes.smallMedium
        visible: root.providers.length > 0

        PlasmaComponents.Label {
            anchors.fill: parent
            text: "󰚩"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: Kirigami.Units.iconSizes.smallMedium
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton)
                    root.launchAgent()
                else if (mouse.button === Qt.MiddleButton)
                    root.nextProvider()
                else
                    plasmoid.expanded = true
            }
        }
    }

    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 28
        Layout.minimumHeight: Kirigami.Units.gridUnit * 24

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.gridUnit
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label {
                    text: "󰚩"
                    font.pixelSize: Kirigami.Units.iconSizes.medium
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        text: root.providers.length > 0 ? String(root.valueOr(root.provider.name, root.provider.id || "Agent")) : "Agents"
                        font.bold: true
                    }
                    PlasmaComponents.Label {
                        text: String(root.valueOr(root.provider.plan, root.provider.status || "Usage"))
                        opacity: 0.7
                    }
                }
                PlasmaComponents.Button {
                    visible: root.providers.length > 1
                    text: "Next"
                    onClicked: root.nextProvider()
                }
            }

            Kirigami.Separator { Layout.fillWidth: true }

            PlasmaComponents.Label {
                visible: root.providers.length === 0
                text: "No AI usage recorded"
                opacity: 0.7
            }

            ColumnLayout {
                visible: root.providers.length > 0
                Layout.fillWidth: true
                PlasmaComponents.Label {
                    text: root.provider.limits && root.provider.limits.length > 0 ? "LIMITS" : "BALANCE"
                    font.bold: true
                }
                Repeater {
                    model: root.provider.limits || []
                    delegate: RowLayout {
                        Layout.fillWidth: true
                        PlasmaComponents.Label { text: String(modelData.title || modelData.name || "Window"); opacity: 0.7 }
                        PlasmaComponents.Label { text: String(modelData.percentUsed !== undefined ? modelData.percentUsed + "%" : root.valueOr(modelData.used, "unknown")); Layout.fillWidth: true; horizontalAlignment: Text.AlignRight }
                    }
                }
                PlasmaComponents.Label {
                    visible: (!root.provider.limits || root.provider.limits.length === 0) && root.provider.balance !== undefined
                    text: root.provider.balance === undefined ? "" : String(root.provider.balance.remaining || root.provider.balance.estimatedRemaining || root.provider.balance)
                    Layout.fillWidth: true
                }
            }

            PlasmaComponents.Label {
                visible: root.providers.length > 0 && root.provider.recentDays && root.provider.recentDays.length > 0
                text: "TOKENS BY DAY"
                font.bold: true
            }
            ListView {
                visible: root.providers.length > 0 && root.provider.recentDays && root.provider.recentDays.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, Kirigami.Units.gridUnit * 7)
                model: root.provider.recentDays || []
                delegate: RowLayout {
                    width: ListView.view.width
                    PlasmaComponents.Label { text: String(modelData.date || "day"); opacity: 0.7 }
                    PlasmaComponents.Label { text: String(modelData.messageCount || modelData.tokens || 0); Layout.fillWidth: true; horizontalAlignment: Text.AlignRight }
                }
            }

            PlasmaComponents.Label {
                visible: root.providers.length > 0 && root.provider.models && root.provider.models.length > 0
                text: "TOKENS BY MODEL"
                font.bold: true
            }
            ListView {
                visible: root.providers.length > 0 && root.provider.models && root.provider.models.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, Kirigami.Units.gridUnit * 6)
                model: root.provider.models || []
                delegate: RowLayout {
                    width: ListView.view.width
                    PlasmaComponents.Label { text: String(modelData.model || modelData.name || "model"); opacity: 0.7; elide: Text.ElideLeft }
                    PlasmaComponents.Label { text: String(modelData.tokens || modelData.totalTokens || 0); Layout.fillWidth: true; horizontalAlignment: Text.AlignRight }
                }
            }

            PlasmaComponents.Label {
                visible: root.lastError !== ""
                text: root.lastError
                color: Kirigami.Theme.negativeTextColor
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Button { text: "Refresh"; onClicked: root.refresh() }
                PlasmaComponents.Button { text: "Launch agent"; onClicked: root.launchAgent() }
            }
        }
    }
}
