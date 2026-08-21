import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../Model.js" as Model

Item {
  id: root

  property var dataModel: null
  property var actionProc: null
  property var onRefresh: null

  readonly property var ports: (dataModel && dataModel.ports) ? dataModel.ports : []

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.space(8)

    // Subheader
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      Text {
        text: "󰒋 Local Listening Ports (" + ports.length + ")"
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.weight: Font.DemiBold
        color: Color.muted
      }

      Item { Layout.fillWidth: true }

      Rectangle {
        width: refreshBtn.implicitWidth + Style.space(12)
        height: Style.space(24)
        radius: Style.cornerRadius
        color: refreshMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)
        border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
        border.width: 1

        RowLayout {
          id: refreshBtn
          anchors.centerIn: parent
          spacing: Style.space(4)

          Text {
            text: "󰑐"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            color: Color.foreground
          }
          Text {
            text: "Refresh"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            color: Color.foreground
          }
        }

        MouseArea {
          id: refreshMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (typeof root.onRefresh === "function") root.onRefresh()
          }
        }
      }
    }

    // List of ports
    ListView {
      id: portsList
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      spacing: Style.space(6)
      model: root.ports

      delegate: Rectangle {
        width: portsList.width
        height: Style.space(48)
        radius: Style.cornerRadius
        color: rowMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)
        border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.1)
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(10)

          // Process Icon
          Text {
            text: Model.getProcessIcon(modelData.process)
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            color: Color.accent
          }

          // Process and PID
          ColumnLayout {
            spacing: Style.space(1)
            Layout.preferredWidth: Style.space(140)

            Text {
              text: modelData.process + (modelData.pid > 0 ? " (PID " + modelData.pid + ")" : "")
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.weight: Font.Medium
              color: Color.foreground
              elide: Text.ElideRight
            }

            Text {
              text: modelData.ip
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: Color.muted
            }
          }

          // Port Badge
          Rectangle {
            Layout.preferredWidth: portText.implicitWidth + Style.space(12)
            Layout.preferredHeight: Style.space(22)
            radius: Style.cornerRadius
            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
            border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3)
            border.width: 1

            Text {
              id: portText
              anchors.centerIn: parent
              text: ":" + modelData.port
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.weight: Font.Bold
              color: Color.accent
            }
          }

          Item { Layout.fillWidth: true }

          // Action Buttons
          // 1. Open in Browser
          Rectangle {
            width: Style.space(28)
            height: Style.space(28)
            radius: Style.cornerRadius
            color: openMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.18) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

            Text {
              anchors.centerIn: parent
              text: "󰐊"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: Color.foreground
            }

            MouseArea {
              id: openMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                var url = Model.formatPortUrl(modelData.ip, modelData.port)
                if (actionProc) {
                  actionProc.command = [Qt.resolvedUrl("../helpers/devenv-action.sh").toString().replace("file://", ""), "open-browser", url]
                  actionProc.running = true
                }
              }
            }
          }

          // 2. Copy URL
          Rectangle {
            width: Style.space(28)
            height: Style.space(28)
            radius: Style.cornerRadius
            color: copyMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.18) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

            Text {
              anchors.centerIn: parent
              text: "󰆏"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: Color.foreground
            }

            MouseArea {
              id: copyMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                var url = Model.formatPortUrl(modelData.ip, modelData.port)
                Quickshell.clipboardText = url
              }
            }
          }

          // 3. Kill Process
          Rectangle {
            width: Style.space(28)
            height: Style.space(28)
            radius: Style.cornerRadius
            color: killMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.3) : Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.1)
            border.color: Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.3)
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: "󰅖"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: Color.urgent
            }

            MouseArea {
              id: killMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (actionProc) {
                  if (modelData.pid > 0) {
                    actionProc.command = [Qt.resolvedUrl("../helpers/devenv-action.sh").toString().replace("file://", ""), "kill-pid", String(modelData.pid)]
                  } else {
                    actionProc.command = [Qt.resolvedUrl("../helpers/devenv-action.sh").toString().replace("file://", ""), "kill-port", String(modelData.port)]
                  }
                  actionProc.running = true
                  Qt.callLater(root.onRefresh)
                }
              }
            }
          }
        }

        MouseArea {
          id: rowMouse
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.NoButton
        }
      }

      // Empty state
      Text {
        anchors.centerIn: parent
        visible: root.ports.length === 0
        text: "󰒋 No active listening ports"
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        color: Color.muted
      }
    }
  }
}
