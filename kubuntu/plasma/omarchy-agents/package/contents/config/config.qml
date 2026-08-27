import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_refreshIntervalSec: refreshInterval.value

    Kirigami.FormLayout {
        Controls.SpinBox {
            id: refreshInterval
            Kirigami.FormData.label: "Usage refresh interval (seconds):"
            from: 60
            to: 86400
            stepSize: 60
        }
    }
}
