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
  property string activeLogContainer: ""
  property string logOutputText: ""
  property bool showingLogs: false

  readonly property var docker: (dataModel && dataModel.docker) ? dataModel.docker : { available: false, containers: [] }
  readonly property var project: (dataModel && dataModel.project) ? dataModel.project : { path: "", name: "", hasCompose: false }

  // Process to fetch logs
  Process {
    id: logProc
    command: [Qt.resolvedUrl("../helpers/devenv-action.sh").toString().replace("file://", ""), "docker-logs", root.activeLogContainer]
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        root.logOutputText += line + "\n"
      }
    }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.space(8)

    // Docker Compose bar if compose file is present
    Rectangle {
      visible: root.project.hasCompose
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(38)
      radius: Style.cornerRadius
      color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.1)
      border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
      border.width: 1

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(10)
        anchors.rightMargin: Style.space(10)
        spacing: Style.space(8)

        Text {
          text: " Docker Compose Detected"
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.weight: Font.DemiBold
          color: Color.accent
        }

        Item { Layout.fillWidth: true }

        // Compose Up Button
        Rectangle {
          width: composeUpText.implicitWidth + Style.space(12)
          height: Style.space(24)
          radius: Style.cornerRadius
          color: upMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

          RowLayout {
            id: composeUpText
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text { text: "󰐊"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
            Text { text: "Compose Up"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
          }

          MouseArea {
            id: upMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (actionProc) {
                actionProc.command = [Qt.resolvedUrl("../helpers/devenv-action.sh").toString().replace("file://", ""), "compose-up", root.project.path]
                actionProc.running = true
                Qt.callLater(root.onRefresh)
              }
            }
          }
        }

        // Compose Down Button
        Rectangle {
          width: composeDownText.implicitWidth + Style.space(12)
          height: Style.space(24)
          radius: Style.cornerRadius
          color: downMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.25) : Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.1)

          RowLayout {
            id: composeDownText
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text { text: "󰅖"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.urgent }
            Text { text: "Down"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.urgent }
          }

          MouseArea {
            id: downMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (actionProc) {
                actionProc.command = [Qt.resolvedUrl("../helpers/devenv-action.sh").toString().replace("file://", ""), "compose-down", root.project.path]
                actionProc.running = true
                Qt.callLater(root.onRefresh)
              }
            }
          }
        }
      }
    }

    // Subheader
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      Text {
        text: " Containers (" + (root.docker.containers ? root.docker.containers.length : 0) + ")"
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.weight: Font.DemiBold
        color: Color.muted
      }

      Item { Layout.fillWidth: true }

      Text {
        visible: !root.docker.available
        text: "󰅖 Docker Daemon Offline"
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        color: Color.urgent
      }
    }

    // Main Container List / Logs view
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true

      ListView {
        id: containerList
        anchors.fill: parent
        visible: !root.showingLogs
        clip: true
        spacing: Style.space(6)
        model: root.docker.containers || []

        delegate: Rectangle {
          width: containerList.width
          height: Style.space(54)
          radius: Style.cornerRadius
          color: cMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)
          border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.1)
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(8)

            // Status Icon
            Text {
              text: Model.getContainerStateIcon(modelData.state)
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              color: modelData.state === "running" ? "#50fa7b" : (modelData.state === "exited" ? Color.muted : Color.urgent)
            }

            // Container info
            ColumnLayout {
              spacing: Style.space(1)
              Layout.preferredWidth: Style.space(160)

              Text {
                text: modelData.name
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.weight: Font.Medium
                color: Color.foreground
                elide: Text.ElideRight
              }

              Text {
                text: modelData.image
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Color.muted
                elide: Text.ElideRight
              }
            }

            // Ports text
            Text {
              Layout.preferredWidth: Style.space(90)
              text: modelData.ports || "no ports"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: Color.muted
              elide: Text.ElideRight
            }

            Item { Layout.fillWidth: true }

            // Action Buttons
            // Start/Stop toggle
            Rectangle {
              width: Style.space(26)
              height: Style.space(26)
              radius: Style.cornerRadius
              color: toggleMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.18) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

              Text {
                anchors.centerIn: parent
                text: modelData.state === "running" ? "󰅖" : "󰐊"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: modelData.state === "running" ? Color.urgent : "#50fa7b"
              }

              MouseArea {
                id: toggleMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (actionProc) {
                    var act = modelData.state === "running" ? "docker-stop" : "docker-start"
                    actionProc.command = [Qt.resolvedUrl("../helpers/devenv-action.sh").toString().replace("file://", ""), act, modelData.id]
                    actionProc.running = true
                    Qt.callLater(root.onRefresh)
                  }
                }
              }
            }

            // Restart Button
            Rectangle {
              width: Style.space(26)
              height: Style.space(26)
              radius: Style.cornerRadius
              color: restMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.18) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

              Text {
                anchors.centerIn: parent
                text: "󰑐"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Color.foreground
              }

              MouseArea {
                id: restMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (actionProc) {
                    actionProc.command = [Qt.resolvedUrl("../helpers/devenv-action.sh").toString().replace("file://", ""), "docker-restart", modelData.id]
                    actionProc.running = true
                    Qt.callLater(root.onRefresh)
                  }
                }
              }
            }

            // View Logs Button
            Rectangle {
              width: Style.space(26)
              height: Style.space(26)
              radius: Style.cornerRadius
              color: logMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.18) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

              Text {
                anchors.centerIn: parent
                text: "󰈙"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Color.foreground
              }

              MouseArea {
                id: logMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.activeLogContainer = modelData.name
                  root.logOutputText = ""
                  root.showingLogs = true
                  logProc.running = true
                }
              }
            }
          }

          MouseArea {
            id: cMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
          }
        }

        // Empty state
        Text {
          anchors.centerIn: parent
          visible: !root.docker.containers || root.docker.containers.length === 0
          text: root.docker.available ? " No active containers" : " Docker service not running"
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          color: Color.muted
        }
      }

      // Logs overlay view
      Rectangle {
        anchors.fill: parent
        visible: root.showingLogs
        radius: Style.cornerRadius
        color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.95)
        border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.2)
        border.width: 1

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.space(8)
          spacing: Style.space(6)

          RowLayout {
            Layout.fillWidth: true
            Text {
              text: "󰈙 Logs: " + root.activeLogContainer
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.weight: Font.Bold
              color: Color.accent
            }
            Item { Layout.fillWidth: true }
            Rectangle {
              width: Style.space(22)
              height: Style.space(22)
              radius: Style.cornerRadius
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.1)
              Text { anchors.centerIn: parent; text: "󰅖"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.showingLogs = false
              }
            }
          }

          Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: logTextItem.width
            contentHeight: logTextItem.height

            Text {
              id: logTextItem
              text: root.logOutputText !== "" ? root.logOutputText : "Loading logs..."
              font.family: "Monospace"
              font.pixelSize: Style.font.caption
              color: Color.foreground
              wrapMode: Text.WrapAnywhere
              width: containerList.width - Style.space(16)
            }
          }
        }
      }
    }
  }
}
