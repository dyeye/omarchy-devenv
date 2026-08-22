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

  function copyToClipboard(text) {
    if (text === undefined || text === null) return
    Quickshell.execDetached(["bash", "-c", "printf %s \"$1\" | wl-copy", "_", String(text)])
  }

  // Process to fetch logs — empty splitMarker caps before line-buffer growth.
  readonly property int maxLogBytes: 131072

  Process {
    id: logProc
    command: [Qt.resolvedUrl("../helpers/devenv-action.sh").toString().replace("file://", ""), "docker-logs", root.activeLogContainer]
    running: false
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        if (!chunk || chunk.length === 0)
          return
        if (root.logOutputText.length >= root.maxLogBytes) {
          if (logProc.running)
            logProc.signal(9)
          return
        }
        var room = root.maxLogBytes - root.logOutputText.length
        if (chunk.length > room) {
          root.logOutputText += chunk.substring(0, room)
          if (logProc.running)
            logProc.signal(9)
        } else {
          root.logOutputText += chunk
        }
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
          color: upMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
          border.color: upMouse.containsMouse ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
          border.width: 1

          RowLayout {
            id: composeUpText
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text { text: "󰐊"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: upMouse.containsMouse ? Color.accent : Color.foreground }
            Text { text: "Compose Up"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: upMouse.containsMouse ? Color.accent : Color.foreground }
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

          PanelToolTip {
            visible: upMouse.containsMouse
            text: "Run docker compose up -d in project"
          }
        }

        // Compose Down Button (with micro confirmation popup)
        Rectangle {
          id: composeDownBtn
          width: composeDownText.implicitWidth + Style.space(12)
          height: Style.space(24)
          radius: Style.cornerRadius
          color: downMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.3) : Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.1)
          border.color: downMouse.containsMouse ? Color.urgent : Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.3)
          border.width: 1

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
            onClicked: composeDownPopup.open()
          }

          PanelToolTip {
            visible: downMouse.containsMouse && !composeDownPopup.visible
            text: "Run docker compose down in project"
          }

          Popup {
            id: composeDownPopup
            x: -(implicitWidth - parent.width)
            y: -implicitHeight - Style.space(4)
            padding: Style.space(4)
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

            background: Rectangle {
              radius: Style.cornerRadius
              color: Color.background
              border.color: Color.urgent
              border.width: 1
            }

            contentItem: RowLayout {
              spacing: Style.space(6)

              Text {
                text: "Compose Down?"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.weight: Font.Bold
                color: Color.urgent
                leftPadding: Style.space(4)
              }

              Rectangle {
                width: cdYesText.implicitWidth + Style.space(12)
                height: Style.space(22)
                radius: Style.cornerRadius
                color: cdYesMouse.containsMouse ? Color.urgent : Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.25)

                Text {
                  id: cdYesText
                  anchors.centerIn: parent
                  text: "Yes"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.weight: Font.Bold
                  color: cdYesMouse.containsMouse ? "#ffffff" : Color.urgent
                }

                MouseArea {
                  id: cdYesMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    composeDownPopup.close()
                    if (actionProc) {
                      actionProc.command = [Qt.resolvedUrl("../helpers/devenv-action.sh").toString().replace("file://", ""), "compose-down", root.project.path]
                      actionProc.running = true
                      Qt.callLater(root.onRefresh)
                    }
                  }
                }
              }

              Rectangle {
                width: cdNoText.implicitWidth + Style.space(12)
                height: Style.space(22)
                radius: Style.cornerRadius
                color: cdNoMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.2) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

                Text {
                  id: cdNoText
                  anchors.centerIn: parent
                  text: "No"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.weight: Font.Medium
                  color: Color.foreground
                }

                MouseArea {
                  id: cdNoMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: composeDownPopup.close()
                }
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

      Rectangle {
        visible: root.docker.available
        width: refreshBtn.implicitWidth + Style.space(12)
        height: Style.space(24)
        radius: Style.cornerRadius
        color: refreshMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.14) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)
        border.color: refreshMouse.containsMouse ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
        border.width: 1

        RowLayout {
          id: refreshBtn
          anchors.centerIn: parent
          spacing: Style.space(4)

          Text {
            text: "󰑐"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            color: refreshMouse.containsMouse ? Color.accent : Color.foreground
          }
          Text {
            text: "Refresh"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            color: refreshMouse.containsMouse ? Color.accent : Color.foreground
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

        PanelToolTip {
          visible: refreshMouse.containsMouse
          text: "Scan Docker containers now"
        }
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
          id: containerCard
          width: containerList.width
          height: Style.space(54)
          radius: Style.cornerRadius
          color: cHoverArea.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)
          border.color: cHoverArea.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.1)
          border.width: 1

          // Background row hover detector placed behind controls
          MouseArea {
            id: cHoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            z: 0
          }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(8)
            z: 1

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
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.weight: Font.Medium
                color: Color.foreground
                elide: Text.ElideRight
              }

              Text {
                text: modelData.image
                textFormat: Text.PlainText
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
              textFormat: Text.PlainText
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: Color.muted
              elide: Text.ElideRight
            }

            Item { Layout.fillWidth: true }

            // Action Buttons
            // 1. Start/Stop toggle (with confirmation popup for Stop)
            Rectangle {
              id: toggleBtn
              width: Style.space(28)
              height: Style.space(28)
              radius: Style.cornerRadius
              color: toggleMouse.containsMouse ? (modelData.state === "running" ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.3) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)) : (modelData.state === "running" ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.1) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08))
              border.color: toggleMouse.containsMouse ? (modelData.state === "running" ? Color.urgent : Color.accent) : (modelData.state === "running" ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.3) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15))
              border.width: 1

              Text {
                anchors.centerIn: parent
                text: modelData.state === "running" ? "󰅖" : "󰐊"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.weight: Font.Bold
                color: modelData.state === "running" ? Color.urgent : (toggleMouse.containsMouse ? Color.accent : "#50fa7b")
              }

              MouseArea {
                id: toggleMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (modelData.state === "running") {
                    stopConfirmPopup.open()
                  } else {
                    if (actionProc) {
                      actionProc.command = [Qt.resolvedUrl("../helpers/devenv-action.sh").toString().replace("file://", ""), "docker-start", modelData.id]
                      actionProc.running = true
                      Qt.callLater(root.onRefresh)
                    }
                  }
                }
              }

              PanelToolTip {
                visible: toggleMouse.containsMouse && !stopConfirmPopup.visible
                text: modelData.state === "running" ? "Stop " + modelData.name : "Start " + modelData.name
              }

              // Stop micro confirmation popup
              Popup {
                id: stopConfirmPopup
                x: -(implicitWidth - parent.width)
                y: -implicitHeight - Style.space(4)
                padding: Style.space(4)
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                background: Rectangle {
                  radius: Style.cornerRadius
                  color: Color.background
                  border.color: Color.urgent
                  border.width: 1
                }

                contentItem: RowLayout {
                  spacing: Style.space(6)

                  Text {
                    text: "Stop " + modelData.name + "?"
                    textFormat: Text.PlainText
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.weight: Font.Bold
                    color: Color.urgent
                    leftPadding: Style.space(4)
                  }

                  // Yes Button
                  Rectangle {
                    width: stopYesText.implicitWidth + Style.space(12)
                    height: Style.space(22)
                    radius: Style.cornerRadius
                    color: stopYesMouse.containsMouse ? Color.urgent : Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.25)

                    Text {
                      id: stopYesText
                      anchors.centerIn: parent
                      text: "Yes"
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      font.weight: Font.Bold
                      color: stopYesMouse.containsMouse ? "#ffffff" : Color.urgent
                    }

                    MouseArea {
                      id: stopYesMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        stopConfirmPopup.close()
                        if (actionProc) {
                          actionProc.command = [Qt.resolvedUrl("../helpers/devenv-action.sh").toString().replace("file://", ""), "docker-stop", modelData.id]
                          actionProc.running = true
                          Qt.callLater(root.onRefresh)
                        }
                      }
                    }
                  }

                  // No Button
                  Rectangle {
                    width: stopNoText.implicitWidth + Style.space(12)
                    height: Style.space(22)
                    radius: Style.cornerRadius
                    color: stopNoMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.2) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

                    Text {
                      id: stopNoText
                      anchors.centerIn: parent
                      text: "No"
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      font.weight: Font.Medium
                      color: Color.foreground
                    }

                    MouseArea {
                      id: stopNoMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: stopConfirmPopup.close()
                    }
                  }
                }
              }
            }

            // 2. Restart Button (with confirmation popup)
            Rectangle {
              id: restBtn
              width: Style.space(28)
              height: Style.space(28)
              radius: Style.cornerRadius
              color: restMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.2) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
              border.color: restMouse.containsMouse ? Color.foreground : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
              border.width: 1

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
                onClicked: restartConfirmPopup.open()
              }

              PanelToolTip {
                visible: restMouse.containsMouse && !restartConfirmPopup.visible
                text: "Restart " + modelData.name
              }

              // Restart micro confirmation popup
              Popup {
                id: restartConfirmPopup
                x: -(implicitWidth - parent.width)
                y: -implicitHeight - Style.space(4)
                padding: Style.space(4)
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                background: Rectangle {
                  radius: Style.cornerRadius
                  color: Color.background
                  border.color: Color.accent
                  border.width: 1
                }

                contentItem: RowLayout {
                  spacing: Style.space(6)

                  Text {
                    text: "Restart " + modelData.name + "?"
                    textFormat: Text.PlainText
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.weight: Font.Bold
                    color: Color.accent
                    leftPadding: Style.space(4)
                  }

                  // Yes Button
                  Rectangle {
                    width: restYesText.implicitWidth + Style.space(12)
                    height: Style.space(22)
                    radius: Style.cornerRadius
                    color: restYesMouse.containsMouse ? Color.accent : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)

                    Text {
                      id: restYesText
                      anchors.centerIn: parent
                      text: "Yes"
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      font.weight: Font.Bold
                      color: restYesMouse.containsMouse ? "#ffffff" : Color.accent
                    }

                    MouseArea {
                      id: restYesMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        restartConfirmPopup.close()
                        if (actionProc) {
                          actionProc.command = [Qt.resolvedUrl("../helpers/devenv-action.sh").toString().replace("file://", ""), "docker-restart", modelData.id]
                          actionProc.running = true
                          Qt.callLater(root.onRefresh)
                        }
                      }
                    }
                  }

                  // No Button
                  Rectangle {
                    width: restNoText.implicitWidth + Style.space(12)
                    height: Style.space(22)
                    radius: Style.cornerRadius
                    color: restNoMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.2) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

                    Text {
                      id: restNoText
                      anchors.centerIn: parent
                      text: "No"
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      font.weight: Font.Medium
                      color: Color.foreground
                    }

                    MouseArea {
                      id: restNoMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: restartConfirmPopup.close()
                    }
                  }
                }
              }
            }

            // 3. View Logs Button
            Rectangle {
              id: logBtn
              width: Style.space(28)
              height: Style.space(28)
              radius: Style.cornerRadius
              color: logMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
              border.color: logMouse.containsMouse ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
              border.width: 1

              Text {
                anchors.centerIn: parent
                text: "󰈙"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: logMouse.containsMouse ? Color.accent : Color.foreground
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

              PanelToolTip {
                visible: logMouse.containsMouse
                text: "View live logs for " + modelData.name
              }
            }
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
              textFormat: Text.PlainText
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.weight: Font.Bold
              color: Color.accent
            }
            Item { Layout.fillWidth: true }

            // Copy logs button
            Rectangle {
              width: Style.space(24)
              height: Style.space(24)
              radius: Style.cornerRadius
              color: copyLogMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.18) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
              border.color: copyLogMouse.containsMouse ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
              border.width: 1

              Text { anchors.centerIn: parent; text: "󰆏"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
              MouseArea {
                id: copyLogMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.copyToClipboard(root.logOutputText)
              }
              PanelToolTip {
                visible: copyLogMouse.containsMouse
                text: "Copy logs to clipboard"
              }
            }

            // Close logs button
            Rectangle {
              width: Style.space(24)
              height: Style.space(24)
              radius: Style.cornerRadius
              color: closeLogMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.3) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.1)
              border.color: closeLogMouse.containsMouse ? Color.urgent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
              border.width: 1

              Text { anchors.centerIn: parent; text: "󰅖"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: closeLogMouse.containsMouse ? Color.urgent : Color.foreground }
              MouseArea {
                id: closeLogMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.showingLogs = false
              }
              PanelToolTip {
                visible: closeLogMouse.containsMouse
                text: "Close logs view"
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
              textFormat: Text.PlainText
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
