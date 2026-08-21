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

  readonly property var project: dataModel.project || { path: "", name: "No Project", stack: "generic", hasCompose: false }
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

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(480))
    contentHeight: panel.fittedContentHeight(Style.space(440))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Rectangle {
        anchors.fill: parent
        color: Color.popups.background
        radius: Style.cornerRadius
        border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
        border.width: 1

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.space(12)
          spacing: Style.space(10)

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
                Layout.preferredWidth: Style.space(210)

                Text {
                  text: root.project.name
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.weight: Font.Bold
                  color: Color.foreground
                  elide: Text.ElideRight
                }

                Text {
                  text: root.project.path
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  color: Color.muted
                  elide: Text.ElideMiddle
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
}
