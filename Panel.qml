import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "tabs"

Panel {
  id: root
  moduleName: "dyeye.devenv"
  ipcTarget: "dyeye.devenv"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property string activeTab: "ports" // "ports" | "docker" | "git" | "toolbox"
  property var dataModel: Model.defaultState()
  property string rawScanOutput: ""

  readonly property var project: dataModel.project || { path: "", name: "No Project", stack: "generic", hasCompose: false, isManual: false }
  readonly property var discoveredProjects: dataModel.discoveredProjects || []
  readonly property var git: dataModel.git || { hasRepo: false, branch: "", lastCommit: "", dirty: 0, staged: 0, untracked: 0, ahead: 0, behind: 0 }
  readonly property var ports: dataModel.ports || []
  readonly property var docker: dataModel.docker || { available: false, containers: [] }

  function open() {
    root.controller.show()
    root.refresh()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  IpcHandler {
    target: "dyeye.devenv"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(); return "ok" }
  }

  // Action process
  Process {
    id: actionProc
    running: false
  }

  // Scan process
  Process {
    id: scanProc
    command: [Qt.resolvedUrl("helpers/devenv-scan.sh").toString().replace("file://", "")]
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        root.rawScanOutput += line + "\n"
      }
    }
    onExited: function(exitCode, exitStatus) {
      if (root.rawScanOutput.trim() !== "") {
        root.dataModel = Model.parseScan(root.rawScanOutput)
      }
      root.rawScanOutput = ""
    }
  }

  // Auto refresh timer
  Timer {
    id: scanTimer
    interval: 3000
    repeat: true
    running: root.opened
    onTriggered: root.refresh()
  }

  function refresh() {
    if (!scanProc.running) {
      rawScanOutput = ""
      scanProc.running = true
    }
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(480))
    contentHeight: panel.fittedContentHeight(Style.space(440))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.space(8)
        spacing: Style.space(8)

          // 1. Header with Project Info & Quick Launchers
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(46)
            radius: Style.cornerRadius
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)
            border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.1)
            border.width: 1

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(10)
              spacing: Style.space(8)

              // Stack / Project Icon
              Text {
                text: Model.getStackIcon(root.project.stack)
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                color: Color.accent
              }

              // Project Title and Path
              ColumnLayout {
                spacing: 0
                Layout.preferredWidth: Style.space(160)

                // Marquee Title Container (Static elide, Marquee on Hover)
                Item {
                  id: titleMarqueeBox
                  Layout.preferredWidth: Style.space(160)
                  Layout.preferredHeight: Style.space(18)
                  clip: true

                  readonly property bool isHovered: titleHover.containsMouse
                  readonly property bool isOverflowing: titleText.implicitWidth > titleMarqueeBox.width

                  onIsHoveredChanged: {
                    if (!isHovered) titleText.x = 0
                  }

                  Text {
                    id: titleText
                    text: root.project.name
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    font.weight: Font.Bold
                    color: Color.foreground
                    y: 0
                    width: titleMarqueeBox.isHovered ? implicitWidth : titleMarqueeBox.width
                    elide: titleMarqueeBox.isHovered ? Text.ElideNone : Text.ElideRight
                  }

                  SequentialAnimation {
                    id: titleMarqueeAnim
                    running: root.opened && titleMarqueeBox.isHovered && titleMarqueeBox.isOverflowing
                    loops: Animation.Infinite

                    PauseAnimation { duration: 600 }
                    NumberAnimation {
                      target: titleText
                      property: "x"
                      from: 0
                      to: -(titleText.implicitWidth - titleMarqueeBox.width + Style.space(10))
                      duration: Math.max(1200, (titleText.implicitWidth - titleMarqueeBox.width) * 30)
                      easing.type: Easing.Linear
                    }
                    PauseAnimation { duration: 1000 }
                    NumberAnimation {
                      target: titleText
                      property: "x"
                      to: 0
                      duration: 400
                      easing.type: Easing.InOutQuad
                    }
                  }

                  MouseArea {
                    id: titleHover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                  }

                  PanelToolTip {
                    visible: titleHover.containsMouse
                    text: root.project.name
                  }
                }

                // Marquee Path Container (Static elide, Marquee on Hover)
                Item {
                  id: marqueeBox
                  Layout.preferredWidth: Style.space(160)
                  Layout.preferredHeight: Style.space(16)
                  clip: true

                  readonly property string shortPath: Model.shortenPath(root.project.path)
                  readonly property bool isHovered: pathHover.containsMouse
                  readonly property bool isOverflowing: pathText.implicitWidth > marqueeBox.width

                  onIsHoveredChanged: {
                    if (!isHovered) pathText.x = 0
                  }

                  Text {
                    id: pathText
                    text: marqueeBox.shortPath
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    color: Color.muted
                    y: 0
                    width: marqueeBox.isHovered ? implicitWidth : marqueeBox.width
                    elide: marqueeBox.isHovered ? Text.ElideNone : Text.ElideRight
                  }

                  SequentialAnimation {
                    id: marqueeAnim
                    running: root.opened && marqueeBox.isHovered && marqueeBox.isOverflowing
                    loops: Animation.Infinite

                    PauseAnimation { duration: 600 }
                    NumberAnimation {
                      target: pathText
                      property: "x"
                      from: 0
                      to: -(pathText.implicitWidth - marqueeBox.width + Style.space(10))
                      duration: Math.max(1200, (pathText.implicitWidth - marqueeBox.width) * 30)
                      easing.type: Easing.Linear
                    }
                    PauseAnimation { duration: 1000 }
                    NumberAnimation {
                      target: pathText
                      property: "x"
                      to: 0
                      duration: 400
                      easing.type: Easing.InOutQuad
                    }
                  }

                  MouseArea {
                    id: pathHover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                  }

                  PanelToolTip {
                    visible: pathHover.containsMouse
                    text: root.project.path
                  }
                }
              }

              // Project Switcher / Pinning Pill
              Rectangle {
                id: projectPill
                Layout.preferredWidth: projectPillRow.implicitWidth + Style.space(12)
                Layout.preferredHeight: Style.space(22)
                radius: Style.cornerRadius
                color: projPillMouse.containsMouse ? (root.project.isManual ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.25) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)) : (root.project.isManual ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.12) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12))
                border.color: projPillMouse.containsMouse ? (root.project.isManual ? Color.urgent : Color.accent) : (root.project.isManual ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.3) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3))
                border.width: 1

                RowLayout {
                  id: projectPillRow
                  anchors.centerIn: parent
                  spacing: Style.space(4)
                  Text {
                    text: root.project.isManual ? "󰐗" : "󰘵"
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    color: root.project.isManual ? Color.urgent : Color.accent
                  }
                  Text {
                    text: root.project.isManual ? "Manual" : "Auto"
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.weight: Font.Bold
                    color: root.project.isManual ? Color.urgent : Color.accent
                  }
                  Text {
                    text: "󰅂"
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    color: root.project.isManual ? Color.urgent : Color.accent
                  }
                }

                MouseArea {
                  id: projPillMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: projectPopup.open()
                }

                PanelToolTip {
                  visible: projPillMouse.containsMouse && !projectPopup.visible
                  text: root.project.isManual
                    ? "Manual mode: Pinned to " + root.project.name + "\nClick to switch project or enable auto-detection"
                    : "Auto-detect: Tracking focused window\nClick to pin a project or browse folder"
                }

                // Project Selector Popup Menu
                Popup {
                  id: projectPopup
                  x: 0
                  y: parent.height + Style.space(4)
                  width: Style.space(250)
                  height: Math.min(Style.space(290), Style.space(130) + (root.discoveredProjects.length * Style.space(34)))
                  padding: Style.space(8)
                  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                  background: Rectangle {
                    radius: Style.cornerRadius
                    color: Color.background
                    border.color: Color.accent
                    border.width: 1
                  }

                  contentItem: ColumnLayout {
                    spacing: Style.space(6)

                    // Header title
                    RowLayout {
                      Layout.fillWidth: true
                      Text {
                        text: "󰘵 Project Selection"
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.weight: Font.Bold
                        color: Color.foreground
                      }
                      Item { Layout.fillWidth: true }
                      Text {
                        text: root.project.isManual ? "Pinned" : "Auto"
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        color: root.project.isManual ? Color.urgent : Color.accent
                      }
                    }

                    // 1. Auto-detect Mode Button
                    Rectangle {
                      Layout.fillWidth: true
                      Layout.preferredHeight: Style.space(26)
                      radius: Style.cornerRadius - 2
                      color: autoBtnMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22) : (!root.project.isManual ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12) : "transparent")
                      border.color: !root.project.isManual ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                      border.width: 1

                      RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Style.space(6)
                        anchors.rightMargin: Style.space(6)
                        spacing: Style.space(6)

                        Text {
                          text: !root.project.isManual ? "󰄳" : "󰘵"
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          color: !root.project.isManual ? Color.accent : Color.muted
                        }
                        Text {
                          text: "Auto-detect (Focused Window)"
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          font.weight: !root.project.isManual ? Font.Bold : Font.Normal
                          color: !root.project.isManual ? Color.accent : Color.foreground
                          Layout.fillWidth: true
                          elide: Text.ElideRight
                        }
                      }

                      MouseArea {
                        id: autoBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          projectPopup.close()
                          actionProc.command = [Qt.resolvedUrl("helpers/devenv-action.sh").toString().replace("file://", ""), "unpin-project"]
                          actionProc.running = true
                          Qt.callLater(root.refresh)
                        }
                      }
                    }

                    // 2. Browse Folder Button (Explorer)
                    Rectangle {
                      Layout.fillWidth: true
                      Layout.preferredHeight: Style.space(26)
                      radius: Style.cornerRadius - 2
                      color: browseBtnMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
                      border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
                      border.width: 1

                      RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Style.space(6)
                        anchors.rightMargin: Style.space(6)
                        spacing: Style.space(6)

                        Text {
                          text: "󰉋"
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          color: Color.accent
                        }
                        Text {
                          text: "Browse Folder (File Dialog)..."
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          color: Color.foreground
                          Layout.fillWidth: true
                          elide: Text.ElideRight
                        }
                      }

                      MouseArea {
                        id: browseBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          projectPopup.close()
                          actionProc.command = [Qt.resolvedUrl("helpers/devenv-action.sh").toString().replace("file://", ""), "pick-project-folder"]
                          actionProc.running = true
                          Qt.callLater(root.refresh)
                        }
                      }
                    }

                    // Divider
                    Rectangle {
                      Layout.fillWidth: true
                      Layout.preferredHeight: 1
                      color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.1)
                    }

                    Text {
                      text: "Known Projects (" + root.discoveredProjects.length + ")"
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      color: Color.muted
                    }

                    // Discovered Projects ListView
                    ListView {
                      id: projListView
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      clip: true
                      spacing: Style.space(3)
                      model: root.discoveredProjects

                      delegate: Rectangle {
                        width: projListView.width
                        height: Style.space(32)
                        radius: Style.cornerRadius - 2
                        color: pItemMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : (modelData.path === root.project.path ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.1) : "transparent")

                        RowLayout {
                          anchors.fill: parent
                          anchors.leftMargin: Style.space(6)
                          anchors.rightMargin: Style.space(6)
                          spacing: Style.space(6)

                          Text {
                            text: Model.getStackIcon(modelData.stack)
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            color: Color.accent
                          }

                          ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true

                            Text {
                              text: modelData.name
                              font.family: Style.font.family
                              font.pixelSize: Style.font.caption
                              font.weight: modelData.path === root.project.path ? Font.Bold : Font.Normal
                              color: modelData.path === root.project.path ? Color.accent : Color.foreground
                              elide: Text.ElideRight
                              Layout.fillWidth: true
                            }

                            Text {
                              text: Model.shortenPath(modelData.path)
                              font.family: Style.font.family
                              font.pixelSize: Style.font.caption
                              color: Color.muted
                              elide: Text.ElideMiddle
                              Layout.fillWidth: true
                            }
                          }

                          Text {
                            visible: modelData.path === root.project.path
                            text: "󰄳"
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            color: Color.accent
                          }
                        }

                        MouseArea {
                          id: pItemMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            projectPopup.close()
                            actionProc.command = [Qt.resolvedUrl("helpers/devenv-action.sh").toString().replace("file://", ""), "pin-project", modelData.path]
                            actionProc.running = true
                            Qt.callLater(root.refresh)
                          }
                        }
                      }
                    }
                  }
                }
              }

              Item { Layout.fillWidth: true }

              // Quick action icons
              // Terminal
              Rectangle {
                width: Style.space(26)
                height: Style.space(26)
                radius: Style.cornerRadius
                color: tMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.18) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                Text { anchors.centerIn: parent; text: ""; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
                MouseArea {
                  id: tMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    actionProc.command = [Qt.resolvedUrl("helpers/devenv-action.sh").toString().replace("file://", ""), "open-terminal", root.project.path]
                    actionProc.running = true
                  }
                }
                PanelToolTip {
                  visible: tMouse.containsMouse
                  text: "Open terminal in project directory"
                }
              }

              // Lazygit
              Rectangle {
                width: Style.space(26)
                height: Style.space(26)
                radius: Style.cornerRadius
                color: lMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.18) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                Text { anchors.centerIn: parent; text: "󰊢"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
                MouseArea {
                  id: lMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    actionProc.command = [Qt.resolvedUrl("helpers/devenv-action.sh").toString().replace("file://", ""), "open-lazygit", root.project.path]
                    actionProc.running = true
                  }
                }
                PanelToolTip {
                  visible: lMouse.containsMouse
                  text: "Open lazygit in project directory"
                }
              }

              // Editor
              Rectangle {
                width: Style.space(26)
                height: Style.space(26)
                radius: Style.cornerRadius
                color: eMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.18) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                Text { anchors.centerIn: parent; text: "󰈙"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
                MouseArea {
                  id: eMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    actionProc.command = [Qt.resolvedUrl("helpers/devenv-action.sh").toString().replace("file://", ""), "open-editor", root.project.path]
                    actionProc.running = true
                  }
                }
                PanelToolTip {
                  visible: eMouse.containsMouse
                  text: "Open project in editor"
                }
              }
            }
          }

          // 2. Navigation Tab Bar
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(32)
            radius: Style.cornerRadius
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)

            RowLayout {
              anchors.fill: parent
              spacing: Style.space(2)

              // Tab 1: Ports
              Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Style.cornerRadius
                color: root.activeTab === "ports" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

                RowLayout {
                  anchors.centerIn: parent
                  spacing: Style.space(4)
                  Text { text: "󰒋"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: root.activeTab === "ports" ? Color.accent : Color.foreground }
                  Text { text: "Ports (" + root.ports.length + ")"; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: root.activeTab === "ports" ? Font.Bold : Font.Normal; color: root.activeTab === "ports" ? Color.accent : Color.foreground }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.activeTab = "ports"
                }
              }

              // Tab 2: Docker
              Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Style.cornerRadius
                color: root.activeTab === "docker" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

                RowLayout {
                  anchors.centerIn: parent
                  spacing: Style.space(4)
                  Text { text: ""; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: root.activeTab === "docker" ? Color.accent : Color.foreground }
                  Text { text: "Docker (" + (root.docker.containers ? root.docker.containers.length : 0) + ")"; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: root.activeTab === "docker" ? Font.Bold : Font.Normal; color: root.activeTab === "docker" ? Color.accent : Color.foreground }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.activeTab = "docker"
                }
              }

              // Tab 3: Git
              Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Style.cornerRadius
                color: root.activeTab === "git" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

                RowLayout {
                  anchors.centerIn: parent
                  spacing: Style.space(4)
                  Text { text: ""; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: root.activeTab === "git" ? Color.accent : Color.foreground }
                  Text { text: "Git" + (root.git.dirty > 0 ? " (~" + root.git.dirty + ")" : ""); font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: root.activeTab === "git" ? Font.Bold : Font.Normal; color: root.activeTab === "git" ? Color.accent : Color.foreground }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.activeTab = "git"
                }
              }

              // Tab 4: Toolbox
              Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Style.cornerRadius
                color: root.activeTab === "toolbox" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"

                RowLayout {
                  anchors.centerIn: parent
                  spacing: Style.space(4)
                  Text { text: "󰞋"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: root.activeTab === "toolbox" ? Color.accent : Color.foreground }
                  Text { text: "Toolbox"; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: root.activeTab === "toolbox" ? Font.Bold : Font.Normal; color: root.activeTab === "toolbox" ? Color.accent : Color.foreground }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.activeTab = "toolbox"
                }
              }
            }
          }

          // 3. Tab Contents Area
          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            PortsTab {
              anchors.fill: parent
              visible: root.activeTab === "ports"
              dataModel: root.dataModel
              actionProc: actionProc
              onRefresh: root.refresh
            }

            DockerTab {
              anchors.fill: parent
              visible: root.activeTab === "docker"
              dataModel: root.dataModel
              actionProc: actionProc
              onRefresh: root.refresh
            }

            GitTab {
              anchors.fill: parent
              visible: root.activeTab === "git"
              dataModel: root.dataModel
              actionProc: actionProc
              onRefresh: root.refresh
            }

            ToolboxTab {
              anchors.fill: parent
              visible: root.activeTab === "toolbox"
            }
          }
        }
      }
    }
  }
