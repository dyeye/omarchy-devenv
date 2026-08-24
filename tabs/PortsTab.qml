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
  readonly property var groupedPorts: Model.groupPorts(root.ports)

  property var collapsedGroups: ({ "General Processes": false })

  function copyToClipboard(text) {
    if (text === undefined || text === null) return
    Quickshell.execDetached(["bash", "-c", "printf %s \"$1\" | wl-copy", "_", String(text)])
  }

  function isGroupCollapsed(groupName) {
    return !!root.collapsedGroups[groupName]
  }

  function toggleGroup(groupName) {
    var next = {}
    for (var k in root.collapsedGroups) {
      next[k] = root.collapsedGroups[k]
    }
    next[groupName] = !next[groupName]
    root.collapsedGroups = next
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.space(8)

    // Subheader
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      Text {
        text: "󰒋 Local Listening Ports (" + root.ports.length + ")"
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
          text: "Scan listening ports now"
        }
      }
    }

    // Scrollable grouped list
    ScrollView {
      id: portsScroll
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true

      ListView {
        id: groupsList
        width: portsScroll.width
        spacing: Style.space(10)
        model: root.groupedPorts

        delegate: ColumnLayout {
          id: groupDelegate
          width: groupsList.width
          spacing: Style.space(6)

          readonly property bool isCollapsed: root.isGroupCollapsed(modelData.name)

          // Clickable Category Header Card
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(26)
            radius: Style.cornerRadius
            color: headerMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.03)
            border.color: headerMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
            border.width: 1

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(6)

              Text {
                text: groupDelegate.isCollapsed ? "󰅂" : "󰅀"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Color.accent
              }

              Text {
                text: modelData.type === "project" ? "󰉋" : ""
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.weight: Font.Bold
                color: modelData.type === "project" ? Color.accent : Color.muted
              }

              Text {
                text: modelData.name
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.weight: Font.Bold
                color: modelData.type === "project" ? Color.accent : Color.muted
              }

              Text {
                visible: modelData.path !== ""
                text: "(" + Model.shortenPath(modelData.path) + ")"
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Color.muted
                elide: Text.ElideMiddle
                Layout.fillWidth: true
              }

              Item { visible: modelData.path === ""; Layout.fillWidth: true }

              Rectangle {
                Layout.preferredWidth: groupCountText.implicitWidth + Style.space(8)
                Layout.preferredHeight: Style.space(18)
                radius: Style.cornerRadius
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

                Text {
                  id: groupCountText
                  anchors.centerIn: parent
                  text: modelData.ports.length + (modelData.ports.length === 1 ? " port" : " ports")
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  color: Color.muted
                }
              }
            }

            MouseArea {
              id: headerMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.toggleGroup(modelData.name)
            }

            PanelToolTip {
              visible: headerMouse.containsMouse
              text: (groupDelegate.isCollapsed ? "Click to expand " : "Click to collapse ") + Model.plain(modelData.name)
            }
          }

          // Ports in this category
          Repeater {
            model: groupDelegate.isCollapsed ? [] : modelData.ports

            delegate: Rectangle {
              id: portRowCard
              Layout.fillWidth: true
              Layout.preferredHeight: Style.space(48)
              radius: Style.cornerRadius
              color: rowHoverArea.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)
              border.color: rowHoverArea.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.1)
              border.width: 1

              // Background row hover detector placed behind controls
              MouseArea {
                id: rowHoverArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                z: 0
              }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(10)
                z: 1

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
                  Layout.preferredWidth: Style.space(145)

                  Text {
                    text: modelData.process + (modelData.pid > 0 ? " (PID " + modelData.pid + ")" : "")
                    textFormat: Text.PlainText
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    font.weight: Font.Medium
                    color: Color.foreground
                    elide: Text.ElideRight
                  }

                  Text {
                    text: modelData.ip
                    textFormat: Text.PlainText
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    color: Color.muted
                  }
                }

                // Port Badge (Clickable to copy)
                Rectangle {
                  id: portBadge
                  Layout.preferredWidth: portText.implicitWidth + Style.space(12)
                  Layout.preferredHeight: Style.space(24)
                  radius: Style.cornerRadius
                  color: badgeMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
                  border.color: badgeMouse.containsMouse ? Color.accent : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3)
                  border.width: 1

                  Text {
                    id: portText
                    anchors.centerIn: parent
                    text: ":" + modelData.port
                    textFormat: Text.PlainText
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.weight: Font.Bold
                    color: Color.accent
                  }

                  MouseArea {
                    id: badgeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      var url = Model.formatPortUrl(modelData.ip, modelData.port)
                      root.copyToClipboard(url)
                    }
                  }

                  PanelToolTip {
                    visible: badgeMouse.containsMouse
                    text: "Click to copy " + Model.formatPortUrl(modelData.ip, modelData.port)
                  }
                }

                Item { Layout.fillWidth: true }

                // Action Buttons
                // 1. Open in Browser
                Rectangle {
                  id: openBtn
                  width: Style.space(28)
                  height: Style.space(28)
                  radius: Style.cornerRadius
                  color: openMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                  border.color: openMouse.containsMouse ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                  border.width: 1

                  Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    color: openMouse.containsMouse ? Color.accent : Color.foreground
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

                  PanelToolTip {
                    visible: openMouse.containsMouse
                    text: "Open " + Model.formatPortUrl(modelData.ip, modelData.port) + " in browser"
                  }
                }

                // 2. Copy URL
                Rectangle {
                  id: copyBtn
                  width: Style.space(28)
                  height: Style.space(28)
                  radius: Style.cornerRadius
                  color: copyMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                  border.color: copyMouse.containsMouse ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                  border.width: 1

                  Text {
                    anchors.centerIn: parent
                    text: "󰆏"
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    color: copyMouse.containsMouse ? Color.accent : Color.foreground
                  }

                  MouseArea {
                    id: copyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      var url = Model.formatPortUrl(modelData.ip, modelData.port)
                      root.copyToClipboard(url)
                    }
                  }

                  PanelToolTip {
                    visible: copyMouse.containsMouse
                    text: "Copy " + Model.formatPortUrl(modelData.ip, modelData.port) + " to clipboard"
                  }
                }

                // 3. Kill Process (with compact inline popup)
                Rectangle {
                  id: killBtn
                  width: Style.space(28)
                  height: Style.space(28)
                  radius: Style.cornerRadius
                  color: killMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.3) : Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.1)
                  border.color: killMouse.containsMouse ? Color.urgent : Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.3)
                  border.width: 1

                  Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.weight: Font.Bold
                    color: Color.urgent
                  }

                  MouseArea {
                    id: killMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: confirmPopup.open()
                  }

                  PanelToolTip {
                    visible: killMouse.containsMouse && !confirmPopup.visible
                    text: modelData.pid > 0 ? "Kill process " + Model.plain(modelData.process) + " (PID " + modelData.pid + ")" : "Kill port :" + modelData.port
                  }

                  // Compact micro confirmation popup
                  Popup {
                    id: confirmPopup
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
                        text: "Kill " + modelData.process + " (PID " + modelData.pid + ")?"
                        textFormat: Text.PlainText
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.weight: Font.Bold
                        color: Color.urgent
                        leftPadding: Style.space(4)
                      }

                      // Yes Button
                      Rectangle {
                        width: yesText.implicitWidth + Style.space(12)
                        height: Style.space(22)
                        radius: Style.cornerRadius
                        color: yesMouse.containsMouse ? Color.urgent : Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.25)

                        Text {
                          id: yesText
                          anchors.centerIn: parent
                          text: "Yes"
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          font.weight: Font.Bold
                          color: yesMouse.containsMouse ? "#ffffff" : Color.urgent
                        }

                        MouseArea {
                          id: yesMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            confirmPopup.close()
                            if (actionProc) {
                              if (modelData.pid > 0) {
                                actionProc.command = [
                                  Qt.resolvedUrl("../helpers/devenv-action.sh").toString().replace("file://", ""),
                                  "kill-pid",
                                  String(modelData.pid),
                                  String(modelData.process || ""),
                                  String(modelData.startTime || "")
                                ]
                              } else {
                                actionProc.command = [
                                  Qt.resolvedUrl("../helpers/devenv-action.sh").toString().replace("file://", ""),
                                  "kill-port",
                                  String(modelData.port)
                                ]
                              }
                              actionProc.running = true
                              Qt.callLater(root.onRefresh)
                            }
                          }
                        }
                      }

                      // No / Cancel Button
                      Rectangle {
                        width: noText.implicitWidth + Style.space(12)
                        height: Style.space(22)
                        radius: Style.cornerRadius
                        color: noMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.2) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)

                        Text {
                          id: noText
                          anchors.centerIn: parent
                          text: "No"
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          font.weight: Font.Medium
                          color: Color.foreground
                        }

                        MouseArea {
                          id: noMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: confirmPopup.close()
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    // Empty state
    Text {
      Layout.alignment: Qt.AlignCenter
      visible: root.ports.length === 0
      text: "󰒋 No active listening ports"
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      color: Color.muted
    }
  }
}
