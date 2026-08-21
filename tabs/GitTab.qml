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

  readonly property var git: (dataModel && dataModel.git) ? dataModel.git : { hasRepo: false, branch: "", lastCommit: "", dirty: 0, staged: 0, untracked: 0, ahead: 0, behind: 0 }
  readonly property var project: (dataModel && dataModel.project) ? dataModel.project : { path: "", name: "" }

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.space(10)

    // Git Status Card
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: root.git.hasRepo ? Style.space(130) : Style.space(90)
      radius: Style.cornerRadius
      color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)
      border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.space(12)
        spacing: Style.space(8)

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          Text {
            text: ""
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            color: Color.accent
          }

          ColumnLayout {
            spacing: Style.space(1)
            Text {
              text: root.git.hasRepo ? (root.git.repoName !== "" ? root.git.repoName : root.project.name) : "No Git Repository"
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.weight: Font.Bold
              color: Color.foreground
            }
            Text {
              text: root.git.hasRepo ? root.git.repoPath : root.project.path
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: Color.muted
              elide: Text.ElideMiddle
              Layout.preferredWidth: Style.space(260)
            }
          }

          Item { Layout.fillWidth: true }

          // Branch pill
          Rectangle {
            visible: root.git.hasRepo
            Layout.preferredWidth: branchText.implicitWidth + Style.space(14)
            Layout.preferredHeight: Style.space(24)
            radius: Style.cornerRadius
            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
            border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3)
            border.width: 1

            RowLayout {
              id: branchText
              anchors.centerIn: parent
              spacing: Style.space(4)
              Text { text: ""; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.accent }
              Text { text: root.git.branch; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold; color: Color.accent }
            }
          }
        }

        // Git Metric Badges
        RowLayout {
          visible: root.git.hasRepo
          Layout.fillWidth: true
          spacing: Style.space(8)

          // Staged badge
          Rectangle {
            Layout.preferredWidth: stagedText.implicitWidth + Style.space(10)
            Layout.preferredHeight: Style.space(22)
            radius: Style.cornerRadius
            color: root.git.staged > 0 ? Qt.rgba(80/255, 250/255, 123/255, 0.15) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)
            border.color: root.git.staged > 0 ? Qt.rgba(80/255, 250/255, 123/255, 0.4) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.1)
            border.width: 1

            Text {
              id: stagedText
              anchors.centerIn: parent
              text: "+" + root.git.staged + " staged"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: root.git.staged > 0 ? "#50fa7b" : Color.muted
            }
          }

          // Modified / Dirty badge
          Rectangle {
            Layout.preferredWidth: dirtyText.implicitWidth + Style.space(10)
            Layout.preferredHeight: Style.space(22)
            radius: Style.cornerRadius
            color: root.git.dirty > 0 ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.15) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)
            border.color: root.git.dirty > 0 ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.4) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.1)
            border.width: 1

            Text {
              id: dirtyText
              anchors.centerIn: parent
              text: "~" + root.git.dirty + " modified"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: root.git.dirty > 0 ? Color.urgent : Color.muted
            }
          }

          // Untracked badge
          Rectangle {
            Layout.preferredWidth: untrackedText.implicitWidth + Style.space(10)
            Layout.preferredHeight: Style.space(22)
            radius: Style.cornerRadius
            color: root.git.untracked > 0 ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)
            border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.1)
            border.width: 1

            Text {
              id: untrackedText
              anchors.centerIn: parent
              text: "?" + root.git.untracked + " untracked"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: Color.muted
            }
          }

          Item { Layout.fillWidth: true }

          // Sync status
          Text {
            text: (root.git.ahead > 0 ? "󰁝 " + root.git.ahead + " ahead " : "") + (root.git.behind > 0 ? "󰁅 " + root.git.behind + " behind" : (root.git.ahead === 0 ? "󰄳 In sync" : ""))
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            color: root.git.ahead > 0 ? Color.accent : Color.muted
          }
        }

        // Last commit
        Text {
          visible: root.git.hasRepo && root.git.lastCommit !== ""
          Layout.fillWidth: true
          text: "󰜎 " + root.git.lastCommit
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          color: Color.muted
          elide: Text.ElideRight
        }
      }
    }

    // Quick Action Launchers
    Text {
      text: "󱥸 Quick Actions"
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.weight: Font.DemiBold
      color: Color.muted
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(10)

      // 1. Open Lazygit
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(42)
        radius: Style.cornerRadius
        color: lzMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
        border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
        border.width: 1

        RowLayout {
          anchors.centerIn: parent
          spacing: Style.space(6)
          Text { text: "󰘐"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.accent }
          Text { text: "Open Lazygit"; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.weight: Font.Medium; color: Color.foreground }
        }

        MouseArea {
          id: lzMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (actionProc) {
              var targetDir = root.git.hasRepo ? root.git.repoPath : root.project.path
              actionProc.command = [Qt.resolvedUrl("../helpers/devenv-action.sh").toString().replace("file://", ""), "open-lazygit", targetDir]
              actionProc.running = true
            }
          }
        }

        PanelToolTip {
          visible: lzMouse.containsMouse
          text: "Open lazygit in " + (root.git.hasRepo ? (root.git.repoName !== "" ? root.git.repoName : root.project.name) : root.project.name)
        }
      }

      // 2. Open Terminal
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(42)
        radius: Style.cornerRadius
        color: termMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
        border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
        border.width: 1

        RowLayout {
          anchors.centerIn: parent
          spacing: Style.space(6)
          Text { text: ""; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.accent }
          Text { text: "Open Terminal"; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.weight: Font.Medium; color: Color.foreground }
        }

        MouseArea {
          id: termMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (actionProc) {
              var targetDir = root.git.hasRepo ? root.git.repoPath : root.project.path
              actionProc.command = [Qt.resolvedUrl("../helpers/devenv-action.sh").toString().replace("file://", ""), "open-terminal", targetDir]
              actionProc.running = true
            }
          }
        }

        PanelToolTip {
          visible: termMouse.containsMouse
          text: "Open terminal in project folder"
        }
      }

      // 3. Open Editor
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(42)
        radius: Style.cornerRadius
        color: editMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
        border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
        border.width: 1

        RowLayout {
          anchors.centerIn: parent
          spacing: Style.space(6)
          Text { text: "󰈙"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.accent }
          Text { text: "Open Editor"; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.weight: Font.Medium; color: Color.foreground }
        }

        MouseArea {
          id: editMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (actionProc) {
              var targetDir = root.git.hasRepo ? root.git.repoPath : root.project.path
              actionProc.command = [Qt.resolvedUrl("../helpers/devenv-action.sh").toString().replace("file://", ""), "open-editor", targetDir]
              actionProc.running = true
            }
          }
        }

        PanelToolTip {
          visible: editMouse.containsMouse
          text: "Open project in code editor"
        }
      }
    }

    Item { Layout.fillHeight: true }
  }
}
