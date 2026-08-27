import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property var status: ({
        installed: false,
        version: "",
        gatewayState: "unknown",
        activeModel: "",
        currentSessionId: "",
        currentSessionTitle: "",
        hermesNodeAvailable: false,
        nodesOnline: 0,
        nodesTotal: 0,
        nodes: {}
    })
    property string lastError: ""
    property string statusCommand: "hermes-status"
    property int refreshIntervalSec: Math.max(10, Number(Plasmoid.configuration.refreshIntervalSec || 15))

    Plasmoid.icon: "applications-science"
    toolTipMainText: "Hermes Harness"
    toolTipSubText: root.status.installed ? root.status.version : "Hermes is not installed"

    function display(value, fallback) {
        var text = String(value === undefined || value === null ? "" : value)
        return text === "" ? fallback : text
    }

    function refresh() {
        if (!executable.connectedSources.includes(root.statusCommand))
            executable.connectSource(root.statusCommand)
    }

    function launchHermes() {
        executable.connectSource("omarchy-agent")
    }

    function acceptData(source, data) {
        if (source === "omarchy-agent") {
            executable.disconnectSource(source)
            return
        }
        try {
            var parsed = JSON.parse(String(data.stdout || ""))
            if (!parsed || typeof parsed !== "object")
                throw new Error("status is not an object")
            root.status = parsed
            root.lastError = ""
        } catch (error) {
            root.lastError = "Status refresh failed"
        }
        executable.disconnectSource(source)
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

    compactRepresentation: Item {
        implicitWidth: Kirigami.Units.iconSizes.smallMedium
        implicitHeight: Kirigami.Units.iconSizes.smallMedium

        PlasmaComponents.Label {
            anchors.fill: parent
            text: root.status.installed ? (root.status.gatewayState === "active" ? "⚕" : "⚕·") : "⚕×"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: Kirigami.Units.iconSizes.smallMedium
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton)
                    root.launchHermes()
                else if (mouse.button === Qt.MiddleButton)
                    root.refresh()
                else
                    plasmoid.expanded = true
            }
        }
    }

    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 24
        Layout.minimumHeight: Kirigami.Units.gridUnit * 18

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.gridUnit
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: "Hermes Harness"
                font.bold: true
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
                Layout.fillWidth: true
            }
            PlasmaComponents.Label {
                text: root.status.installed ? root.display(root.status.version, "Installed") : "NOT INSTALLED"
                opacity: 0.7
                Layout.fillWidth: true
            }

            Kirigami.Separator { Layout.fillWidth: true }

            GridLayout {
                columns: 2
                Layout.fillWidth: true
                PlasmaComponents.Label { text: "Gateway"; opacity: 0.7 }
                PlasmaComponents.Label { text: root.display(root.status.gatewayState, "unknown"); Layout.fillWidth: true; horizontalAlignment: Text.AlignRight }
                PlasmaComponents.Label { text: "Active model"; opacity: 0.7 }
                PlasmaComponents.Label { text: root.display(root.status.activeModel, "unknown"); Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft }
                PlasmaComponents.Label { text: "Session"; opacity: 0.7 }
                PlasmaComponents.Label { text: root.display(root.status.currentSessionTitle, root.display(root.status.currentSessionId, "none")); Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft }
                PlasmaComponents.Label { text: "Federated nodes"; opacity: 0.7 }
                PlasmaComponents.Label { text: root.status.hermesNodeAvailable ? (Number(root.status.nodesOnline || 0) + "/" + Number(root.status.nodesTotal || 0) + " online") : "hermes-node unavailable"; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight }
            }

            PlasmaComponents.Label {
                visible: root.lastError !== ""
                text: root.lastError
                color: Kirigami.Theme.negativeTextColor
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Button {
                    text: "Refresh"
                    onClicked: root.refresh()
                }
                PlasmaComponents.Button {
                    text: "Open Hermes"
                    onClicked: root.launchHermes()
                }
            }
        }
    }
}
