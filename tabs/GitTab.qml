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
  property string gitSubTab: "commits" // "commits" | "prs" | "issues" | "stashes"

  readonly property var git: (dataModel && dataModel.git) ? dataModel.git : {
    hasRepo: false,
    repoPath: "",
    repoName: "",
    branch: "",
    branches: [],
    lastCommit: "",
    commits: [],
    stashes: [],
    dirty: 0,
    staged: 0,
    untracked: 0,
    ahead: 0,
    behind: 0,
    remoteUrl: "",
    isGitHub: false,
    githubRepo: "",
    pullRequests: [],
    issues: []
  }
  readonly property var project: (dataModel && dataModel.project) ? dataModel.project : { path: "", name: "" }

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.space(8)

    // 1. Git Repository Header & Actions Card
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(92)
      radius: Style.cornerRadius
      color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)
      border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.space(8)
        spacing: Style.space(6)

        // Top Row: Repo Title + Launchers
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          Text {
            text: root.git.isGitHub ? "" : "󰊢"
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            color: Color.accent
          }

          ColumnLayout {
            spacing: 0
            Layout.fillWidth: true
            Layout.maximumWidth: Style.space(210)

            // Marquee Repo Name (Static with '...', Marquee on Hover)
            Item {
              id: gitRepoNameMarqueeBox
              Layout.fillWidth: true
              Layout.preferredHeight: Style.space(18)
              clip: true

              readonly property string repoTitle: root.git.hasRepo ? (root.git.repoName !== "" ? root.git.repoName : root.project.name) : "No Git Repository"
              readonly property bool isHovered: gitRepoNameHover.containsMouse
              readonly property bool isOverflowing: gitRepoNameText.implicitWidth > gitRepoNameMarqueeBox.width

              onIsHoveredChanged: {
                if (!isHovered) gitRepoNameText.x = 0
              }

              Text {
                id: gitRepoNameText
                text: gitRepoNameMarqueeBox.repoTitle
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.weight: Font.Bold
                color: Color.foreground
                y: 0
                width: gitRepoNameMarqueeBox.isHovered ? implicitWidth : gitRepoNameMarqueeBox.width
                elide: gitRepoNameMarqueeBox.isHovered ? Text.ElideNone : Text.ElideRight
              }

              SequentialAnimation {
                id: gitRepoNameAnim
                running: gitRepoNameMarqueeBox.isHovered && gitRepoNameMarqueeBox.isOverflowing
                loops: Animation.Infinite

                PauseAnimation { duration: 600 }
                NumberAnimation {
                  target: gitRepoNameText
                  property: "x"
                  from: 0
                  to: -(gitRepoNameText.implicitWidth - gitRepoNameMarqueeBox.width + Style.space(8))
                  duration: Math.max(1200, (gitRepoNameText.implicitWidth - gitRepoNameMarqueeBox.width) * 30)
                  easing.type: Easing.Linear
                }
                PauseAnimation { duration: 1000 }
                NumberAnimation {
                  target: gitRepoNameText
                  property: "x"
                  to: 0
                  duration: 400
                  easing.type: Easing.InOutQuad
                }
              }

              MouseArea {
                id: gitRepoNameHover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
              }

              PanelToolTip {
                visible: gitRepoNameHover.containsMouse
                text: gitRepoNameMarqueeBox.repoTitle
              }
            }

            // Marquee Repo Path (Static with '...', Marquee on Hover)
            Item {
              id: gitMarqueeBox
              Layout.fillWidth: true
              Layout.preferredHeight: Style.space(16)
              clip: true

              readonly property string rawPath: root.git.hasRepo ? root.git.repoPath : root.project.path
              readonly property string shortPath: Model.shortenPath(rawPath)
              readonly property bool isHovered: gitPathHover.containsMouse
              readonly property bool isOverflowing: gitPathText.implicitWidth > gitMarqueeBox.width

              onIsHoveredChanged: {
                if (!isHovered) gitPathText.x = 0
              }

              Text {
                id: gitPathText
                text: gitMarqueeBox.shortPath
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Color.muted
                y: 0
                width: gitMarqueeBox.isHovered ? implicitWidth : gitMarqueeBox.width
                elide: gitMarqueeBox.isHovered ? Text.ElideNone : Text.ElideRight
              }

              SequentialAnimation {
                id: gitMarqueeAnim
                running: gitMarqueeBox.isHovered && gitMarqueeBox.isOverflowing
                loops: Animation.Infinite

                PauseAnimation { duration: 600 }
                NumberAnimation {
                  target: gitPathText
                  property: "x"
                  from: 0
                  to: -(gitPathText.implicitWidth - gitMarqueeBox.width + Style.space(10))
                  duration: Math.max(1200, (gitPathText.implicitWidth - gitMarqueeBox.width) * 30)
                  easing.type: Easing.Linear
                }
                PauseAnimation { duration: 1000 }
                NumberAnimation {
                  target: gitPathText
                  property: "x"
                  to: 0
                  duration: 400
                  easing.type: Easing.InOutQuad
                }
              }

              MouseArea {
                id: gitPathHover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
              }

              PanelToolTip {
                visible: gitPathHover.containsMouse
                text: gitMarqueeBox.rawPath
              }
            }
          }

          Item { Layout.fillWidth: true }

          // Quick Launcher Action Icons
          // 1. GitHub Repo Web Link
          Rectangle {
            visible: root.git.isGitHub && root.git.githubRepo !== ""
            width: Style.space(26)
            height: Style.space(26)
            radius: Style.cornerRadius
            color: ghMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
            border.color: ghMouse.containsMouse ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: ""
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: ghMouse.containsMouse ? Color.accent : Color.foreground
            }

            MouseArea {
              id: ghMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (actionProc) {
                  actionProc.command = [Qt.resolvedUrl("../helpers/devenv-action.sh").toString().replace("file://", ""), "open-browser", "https://github.com/" + root.git.githubRepo]
                  actionProc.running = true
                }
              }
            }

            PanelToolTip {
              visible: ghMouse.containsMouse
              text: "Open github.com/" + root.git.githubRepo
            }
          }

          // 2. Lazygit
          Rectangle {
            width: Style.space(26)
            height: Style.space(26)
            radius: Style.cornerRadius
            color: lzMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
            border.color: lzMouse.containsMouse ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: "󰘐"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: lzMouse.containsMouse ? Color.accent : Color.foreground
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
              text: "Open Lazygit terminal"
            }
          }

          // 3. Terminal
          Rectangle {
            width: Style.space(26)
            height: Style.space(26)
            radius: Style.cornerRadius
            color: termMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.2) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
            border.color: termMouse.containsMouse ? Color.foreground : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: ""
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: Color.foreground
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
              text: "Open Terminal in repo"
            }
          }

          // 4. Editor
          Rectangle {
            width: Style.space(26)
            height: Style.space(26)
            radius: Style.cornerRadius
            color: editMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.2) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
            border.color: editMouse.containsMouse ? Color.foreground : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: "󰈙"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: Color.foreground
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
              text: "Open Code Editor"
            }
          }

          // 5. Fetch / Pull
          Rectangle {
            width: Style.space(26)
            height: Style.space(26)
            radius: Style.cornerRadius
            color: fetchMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
            border.color: fetchMouse.containsMouse ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: "󰑐"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: fetchMouse.containsMouse ? Color.accent : Color.foreground
            }

            MouseArea {
              id: fetchMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (actionProc) {
                  actionProc.command = [Qt.resolvedUrl("../helpers/devenv-action.sh").toString().replace("file://", ""), "git-fetch", root.git.repoPath]
                  actionProc.running = true
                  Qt.callLater(root.onRefresh)
                }
              }
            }

            PanelToolTip {
              visible: fetchMouse.containsMouse
              text: "Fetch remote updates"
            }
          }
        }

        // Metrics Pills Row (with interactive Active Branch Dropdown Pill)
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(6)

          // Active Branch Dropdown Pill
          Rectangle {
            id: branchPill
            visible: root.git.hasRepo
            Layout.preferredWidth: branchPillRow.implicitWidth + Style.space(12)
            Layout.preferredHeight: Style.space(22)
            radius: Style.cornerRadius
            color: brPillMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
            border.color: brPillMouse.containsMouse ? Color.accent : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3)
            border.width: 1

            RowLayout {
              id: branchPillRow
              anchors.centerIn: parent
              spacing: Style.space(4)
              Text { text: "󰊢"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.accent }
              Text { text: root.git.branch || "HEAD"; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.Bold; color: Color.accent }
              Text { text: "󰅂"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.accent }
            }

            MouseArea {
              id: brPillMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: branchPopup.open()
            }

            PanelToolTip {
              visible: brPillMouse.containsMouse && !branchPopup.visible
              text: "Click to switch branch (" + (root.git.branches ? root.git.branches.length : 0) + " available)"
            }

            // Branch Dropdown Menu Popup (Anchored directly to this pill)
            Popup {
              id: branchPopup
              x: 0
              y: parent.height + Style.space(4)
              width: Style.space(170)
              height: Math.min(Style.space(150), (root.git.branches ? root.git.branches.length * Style.space(28) + Style.space(12) : Style.space(36)))
              padding: Style.space(4)
              closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

              background: Rectangle {
                radius: Style.cornerRadius
                color: Color.background
                border.color: Color.accent
                border.width: 1
              }

              contentItem: ListView {
                id: branchListView
                clip: true
                spacing: Style.space(2)
                model: root.git.branches || []

                delegate: Rectangle {
                  width: branchListView.width
                  height: Style.space(26)
                  radius: Style.cornerRadius - 2
                  color: bMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22) : (modelData === root.git.branch ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.1) : "transparent")

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(6)
                    anchors.rightMargin: Style.space(6)
                    spacing: Style.space(6)

                    Text {
                      text: modelData === root.git.branch ? "󰄳" : "󰊢"
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      color: modelData === root.git.branch ? Color.accent : Color.muted
                    }

                    Text {
                      text: modelData
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      font.weight: modelData === root.git.branch ? Font.Bold : Font.Normal
                      color: modelData === root.git.branch ? Color.accent : Color.foreground
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }
                  }

                  MouseArea {
                    id: bMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      branchPopup.close()
                      if (actionProc && modelData !== root.git.branch) {
                        actionProc.command = [Qt.resolvedUrl("../helpers/devenv-action.sh").toString().replace("file://", ""), "git-checkout", root.git.repoPath, modelData]
                        actionProc.running = true
                        Qt.callLater(root.onRefresh)
                      }
                    }
                  }
                }
              }
            }
          }

          // Staged
          Rectangle {
            Layout.preferredWidth: stagedText.implicitWidth + Style.space(10)
            Layout.preferredHeight: Style.space(20)
            radius: Style.cornerRadius
            color: root.git.staged > 0 ? Qt.rgba(0.3, 0.85, 0.4, 0.2) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
            Text {
              id: stagedText
              anchors.centerIn: parent
              text: "󰄳 " + root.git.staged + " staged"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: root.git.staged > 0 ? "#50fa7b" : Color.muted
            }
          }

          // Modified
          Rectangle {
            Layout.preferredWidth: dirtyText.implicitWidth + Style.space(10)
            Layout.preferredHeight: Style.space(20)
            radius: Style.cornerRadius
            color: root.git.dirty > 0 ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
            Text {
              id: dirtyText
              anchors.centerIn: parent
              text: "󰈙 " + root.git.dirty + " modified"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: root.git.dirty > 0 ? Color.accent : Color.muted
            }
          }

          // Untracked
          Rectangle {
            Layout.preferredWidth: untrackedText.implicitWidth + Style.space(10)
            Layout.preferredHeight: Style.space(20)
            radius: Style.cornerRadius
            color: root.git.untracked > 0 ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.15) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
            Text {
              id: untrackedText
              anchors.centerIn: parent
              text: "󰋜 " + root.git.untracked + " untracked"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: root.git.untracked > 0 ? Color.urgent : Color.muted
            }
          }

          Item { Layout.fillWidth: true }

          // Ahead / Behind
          Rectangle {
            visible: root.git.ahead > 0 || root.git.behind > 0
            Layout.preferredWidth: syncText.implicitWidth + Style.space(10)
            Layout.preferredHeight: Style.space(20)
            radius: Style.cornerRadius
            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
            Text {
              id: syncText
              anchors.centerIn: parent
              text: (root.git.ahead > 0 ? "󰁝 " + root.git.ahead : "") + (root.git.behind > 0 ? " 󰁅 " + root.git.behind : "")
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.weight: Font.Bold
              color: Color.accent
            }
          }
        }
      }
    }

    // 2. Sub-tab navigation bar (Commits, Pull Requests, Issues, Stashes)
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(30)
      radius: Style.cornerRadius
      color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)
      border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
      border.width: 1

      RowLayout {
        anchors.fill: parent
        anchors.margins: Style.space(2)
        spacing: Style.space(4)

        // Tab: Commits
        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          radius: Style.cornerRadius - 2
          color: root.gitSubTab === "commits" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : (cTabMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : "transparent")

          RowLayout {
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text { text: "󰜘"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: root.gitSubTab === "commits" ? Color.accent : Color.foreground }
            Text {
              text: "Commits (" + (root.git.commits ? root.git.commits.length : 0) + ")"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.weight: root.gitSubTab === "commits" ? Font.Bold : Font.Normal
              color: root.gitSubTab === "commits" ? Color.accent : Color.foreground
              elide: Text.ElideRight
            }
          }
          MouseArea { id: cTabMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.gitSubTab = "commits" }
        }

        // Tab: PRs
        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          radius: Style.cornerRadius - 2
          color: root.gitSubTab === "prs" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : (prTabMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : "transparent")

          RowLayout {
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text { text: ""; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: root.gitSubTab === "prs" ? Color.accent : Color.foreground }
            Text {
              text: "PRs (" + (root.git.pullRequests ? root.git.pullRequests.length : 0) + ")"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.weight: root.gitSubTab === "prs" ? Font.Bold : Font.Normal
              color: root.gitSubTab === "prs" ? Color.accent : Color.foreground
              elide: Text.ElideRight
            }
          }
          MouseArea { id: prTabMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.gitSubTab = "prs" }
        }

        // Tab: Issues
        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          radius: Style.cornerRadius - 2
          color: root.gitSubTab === "issues" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : (issTabMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : "transparent")

          RowLayout {
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text { text: ""; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: root.gitSubTab === "issues" ? Color.accent : Color.foreground }
            Text {
              text: "Issues (" + (root.git.issues ? root.git.issues.length : 0) + ")"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.weight: root.gitSubTab === "issues" ? Font.Bold : Font.Normal
              color: root.gitSubTab === "issues" ? Color.accent : Color.foreground
              elide: Text.ElideRight
            }
          }
          MouseArea { id: issTabMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.gitSubTab = "issues" }
        }

        // Tab: Stashes
        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          radius: Style.cornerRadius - 2
          color: root.gitSubTab === "stashes" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : (stTabMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : "transparent")

          RowLayout {
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text { text: "󰅖"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: root.gitSubTab === "stashes" ? Color.accent : Color.foreground }
            Text {
              text: "Stashes (" + (root.git.stashes ? root.git.stashes.length : 0) + ")"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.weight: root.gitSubTab === "stashes" ? Font.Bold : Font.Normal
              color: root.gitSubTab === "stashes" ? Color.accent : Color.foreground
              elide: Text.ElideRight
            }
          }
          MouseArea { id: stTabMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.gitSubTab = "stashes" }
        }
      }
    }

    // 3. Sub-Tab Content Views
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true

      // 3A. Commits View (Static elide with '...', Marquee on Hover)
      ListView {
        id: commitsList
        anchors.fill: parent
        visible: root.gitSubTab === "commits"
        clip: true
        spacing: Style.space(6)
        model: root.git.commits || []

        delegate: Rectangle {
          id: commitRow
          width: commitsList.width
          height: Style.space(46)
          radius: Style.cornerRadius
          color: commitMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)
          border.color: commitMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.1)
          border.width: 1

          // Background row hover
          MouseArea {
            id: commitMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            z: 0
          }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)
            z: 1

            // Commit Hash Badge (Click to copy)
            Rectangle {
              Layout.preferredWidth: Style.space(64)
              Layout.preferredHeight: Style.space(22)
              radius: Style.cornerRadius
              color: hashMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
              border.color: hashMouse.containsMouse ? Color.accent : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
              border.width: 1

              Text {
                id: hashText
                anchors.centerIn: parent
                text: modelData.hash
                font.family: "Monospace"
                font.pixelSize: Style.font.caption
                font.weight: Font.Bold
                color: Color.accent
                elide: Text.ElideRight
              }

              MouseArea {
                id: hashMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.clipboardText = modelData.fullHash || modelData.hash
              }

              PanelToolTip {
                visible: hashMouse.containsMouse
                text: "Click to copy commit hash (" + modelData.hash + ")"
              }
            }

            // Message and Author/Date
            ColumnLayout {
              spacing: 0
              Layout.fillWidth: true

              // Marquee Commit Message (Static elide with '...', Marquee on Hover)
              Item {
                id: commitMsgMarquee
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(16)
                clip: true

                readonly property bool isHovered: commitMouse.containsMouse
                readonly property bool isOverflowing: cMsgText.implicitWidth > commitMsgMarquee.width

                onIsHoveredChanged: {
                  if (!isHovered) cMsgText.x = 0
                }

                Text {
                  id: cMsgText
                  text: modelData.message
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.weight: Font.Medium
                  color: Color.foreground
                  y: 0
                  width: commitMsgMarquee.isHovered ? implicitWidth : commitMsgMarquee.width
                  elide: commitMsgMarquee.isHovered ? Text.ElideNone : Text.ElideRight
                }

                SequentialAnimation {
                  id: cMsgAnim
                  running: commitMsgMarquee.isHovered && commitMsgMarquee.isOverflowing
                  loops: Animation.Infinite

                  PauseAnimation { duration: 600 }
                  NumberAnimation {
                    target: cMsgText
                    property: "x"
                    from: 0
                    to: -(cMsgText.implicitWidth - commitMsgMarquee.width + Style.space(8))
                    duration: Math.max(1200, (cMsgText.implicitWidth - commitMsgMarquee.width) * 30)
                    easing.type: Easing.Linear
                  }
                  PauseAnimation { duration: 1000 }
                  NumberAnimation {
                    target: cMsgText
                    property: "x"
                    to: 0
                    duration: 400
                    easing.type: Easing.InOutQuad
                  }
                }
              }

              Text {
                text: modelData.author + " • " + modelData.date
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Color.muted
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
            }
          }

          PanelToolTip {
            visible: commitMouse.containsMouse && !hashMouse.containsMouse
            text: modelData.message + "\n" + modelData.author + " (" + modelData.date + ")"
          }
        }

        // Empty commits state
        Text {
          anchors.centerIn: parent
          visible: !root.git.commits || root.git.commits.length === 0
          text: root.git.hasRepo ? "󰜘 No commit history" : "󰊢 No Git repository found"
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          color: Color.muted
        }
      }

      // 3B. Pull Requests View (Static elide with '...', Marquee on Hover)
      ListView {
        id: prList
        anchors.fill: parent
        visible: root.gitSubTab === "prs"
        clip: true
        spacing: Style.space(6)
        model: root.git.pullRequests || []

        delegate: Rectangle {
          id: prRow
          width: prList.width
          height: Style.space(48)
          radius: Style.cornerRadius
          color: prRowMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)
          border.color: prRowMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.1)
          border.width: 1

          MouseArea {
            id: prRowMouse
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

            Text {
              text: ""
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              color: "#50fa7b"
            }

            ColumnLayout {
              spacing: 0
              Layout.fillWidth: true

              // Marquee PR Title (Static elide with '...', Marquee on Hover)
              Item {
                id: prTitleMarquee
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(18)
                clip: true

                readonly property string fullPrTitle: "#" + modelData.number + " " + modelData.title
                readonly property bool isHovered: prRowMouse.containsMouse
                readonly property bool isOverflowing: prTitleText.implicitWidth > prTitleMarquee.width

                onIsHoveredChanged: {
                  if (!isHovered) prTitleText.x = 0
                }

                Text {
                  id: prTitleText
                  text: prTitleMarquee.fullPrTitle
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.weight: Font.Medium
                  color: Color.foreground
                  y: 0
                  width: prTitleMarquee.isHovered ? implicitWidth : prTitleMarquee.width
                  elide: prTitleMarquee.isHovered ? Text.ElideNone : Text.ElideRight
                }

                SequentialAnimation {
                  id: prTitleAnim
                  running: prTitleMarquee.isHovered && prTitleMarquee.isOverflowing
                  loops: Animation.Infinite

                  PauseAnimation { duration: 600 }
                  NumberAnimation {
                    target: prTitleText
                    property: "x"
                    from: 0
                    to: -(prTitleText.implicitWidth - prTitleMarquee.width + Style.space(8))
                    duration: Math.max(1200, (prTitleText.implicitWidth - prTitleMarquee.width) * 30)
                    easing.type: Easing.Linear
                  }
                  PauseAnimation { duration: 1000 }
                  NumberAnimation {
                    target: prTitleText
                    property: "x"
                    to: 0
                    duration: 400
                    easing.type: Easing.InOutQuad
                  }
                }
              }

              Text {
                text: "by " + modelData.author + (modelData.headRefName ? " (" + modelData.headRefName + ")" : "")
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Color.muted
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
            }

            // Open PR in Browser Button
            Rectangle {
              width: Style.space(26)
              height: Style.space(26)
              radius: Style.cornerRadius
              color: openPrMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
              border.color: openPrMouse.containsMouse ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
              border.width: 1

              Text {
                anchors.centerIn: parent
                text: "󰐊"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: openPrMouse.containsMouse ? Color.accent : Color.foreground
              }

              MouseArea {
                id: openPrMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (actionProc && modelData.url) {
                    actionProc.command = [Qt.resolvedUrl("../helpers/devenv-action.sh").toString().replace("file://", ""), "open-browser", modelData.url]
                    actionProc.running = true
                  }
                }
              }

              PanelToolTip {
                visible: openPrMouse.containsMouse
                text: "Open PR #" + modelData.number + " in browser"
              }
            }
          }

          PanelToolTip {
            visible: prRowMouse.containsMouse && !openPrMouse.containsMouse
            text: "#" + modelData.number + " " + modelData.title + "\nby " + modelData.author
          }
        }

        // Empty PRs state
        ColumnLayout {
          anchors.centerIn: parent
          visible: !root.git.pullRequests || root.git.pullRequests.length === 0
          spacing: Style.space(6)

          Text {
            Layout.alignment: Qt.AlignCenter
            text: root.git.isGitHub ? " No open Pull Requests" : " Not a GitHub repository"
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            color: Color.muted
          }

          Rectangle {
            visible: root.git.isGitHub && root.git.githubRepo !== ""
            Layout.alignment: Qt.AlignCenter
            width: newPrText.implicitWidth + Style.space(16)
            height: Style.space(26)
            radius: Style.cornerRadius
            color: newPrMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
            border.color: Color.accent
            border.width: 1

            Text {
              id: newPrText
              anchors.centerIn: parent
              text: " Create Pull Request"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.weight: Font.Bold
              color: Color.accent
            }

            MouseArea {
              id: newPrMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (actionProc) {
                  actionProc.command = [Qt.resolvedUrl("../helpers/devenv-action.sh").toString().replace("file://", ""), "open-browser", "https://github.com/" + root.git.githubRepo + "/pulls"]
                  actionProc.running = true
                }
              }
            }
          }
        }
      }

      // 3C. Issues View (Static elide with '...', Marquee on Hover)
      ListView {
        id: issuesList
        anchors.fill: parent
        visible: root.gitSubTab === "issues"
        clip: true
        spacing: Style.space(6)
        model: root.git.issues || []

        delegate: Rectangle {
          id: issRow
          width: issuesList.width
          height: Style.space(46)
          radius: Style.cornerRadius
          color: issRowMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)
          border.color: issRowMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.1)
          border.width: 1

          MouseArea {
            id: issRowMouse
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

            Text {
              text: ""
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              color: Color.accent
            }

            ColumnLayout {
              spacing: 0
              Layout.fillWidth: true

              // Marquee Issue Title (Static elide with '...', Marquee on Hover)
              Item {
                id: issTitleMarquee
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(18)
                clip: true

                readonly property string fullIssTitle: "#" + modelData.number + " " + modelData.title
                readonly property bool isHovered: issRowMouse.containsMouse
                readonly property bool isOverflowing: issTitleText.implicitWidth > issTitleMarquee.width

                onIsHoveredChanged: {
                  if (!isHovered) issTitleText.x = 0
                }

                Text {
                  id: issTitleText
                  text: issTitleMarquee.fullIssTitle
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.weight: Font.Medium
                  color: Color.foreground
                  y: 0
                  width: issTitleMarquee.isHovered ? implicitWidth : issTitleMarquee.width
                  elide: issTitleMarquee.isHovered ? Text.ElideNone : Text.ElideRight
                }

                SequentialAnimation {
                  id: issTitleAnim
                  running: issTitleMarquee.isHovered && issTitleMarquee.isOverflowing
                  loops: Animation.Infinite

                  PauseAnimation { duration: 600 }
                  NumberAnimation {
                    target: issTitleText
                    property: "x"
                    from: 0
                    to: -(issTitleText.implicitWidth - issTitleMarquee.width + Style.space(8))
                    duration: Math.max(1200, (issTitleText.implicitWidth - issTitleMarquee.width) * 30)
                    easing.type: Easing.Linear
                  }
                  PauseAnimation { duration: 1000 }
                  NumberAnimation {
                    target: issTitleText
                    property: "x"
                    to: 0
                    duration: 400
                    easing.type: Easing.InOutQuad
                  }
                }
              }

              Text {
                text: "opened by " + modelData.author
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Color.muted
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
            }

            // Open Issue in Browser Button
            Rectangle {
              width: Style.space(26)
              height: Style.space(26)
              radius: Style.cornerRadius
              color: openIssMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
              border.color: openIssMouse.containsMouse ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
              border.width: 1

              Text {
                anchors.centerIn: parent
                text: "󰐊"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: openIssMouse.containsMouse ? Color.accent : Color.foreground
              }

              MouseArea {
                id: openIssMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (actionProc && modelData.url) {
                    actionProc.command = [Qt.resolvedUrl("../helpers/devenv-action.sh").toString().replace("file://", ""), "open-browser", modelData.url]
                    actionProc.running = true
                  }
                }
              }

              PanelToolTip {
                visible: openIssMouse.containsMouse
                text: "Open Issue #" + modelData.number + " in browser"
              }
            }
          }

          PanelToolTip {
            visible: issRowMouse.containsMouse && !openIssMouse.containsMouse
            text: "#" + modelData.number + " " + modelData.title + "\nopened by " + modelData.author
          }
        }

        // Empty Issues state
        ColumnLayout {
          anchors.centerIn: parent
          visible: !root.git.issues || root.git.issues.length === 0
          spacing: Style.space(6)

          Text {
            Layout.alignment: Qt.AlignCenter
            text: root.git.isGitHub ? " No open Issues" : " Not a GitHub repository"
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            color: Color.muted
          }

          Rectangle {
            visible: root.git.isGitHub && root.git.githubRepo !== ""
            Layout.alignment: Qt.AlignCenter
            width: newIssText.implicitWidth + Style.space(16)
            height: Style.space(26)
            radius: Style.cornerRadius
            color: newIssMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
            border.color: Color.accent
            border.width: 1

            Text {
              id: newIssText
              anchors.centerIn: parent
              text: " Create Issue"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.weight: Font.Bold
              color: Color.accent
            }

            MouseArea {
              id: newIssMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (actionProc) {
                  actionProc.command = [Qt.resolvedUrl("../helpers/devenv-action.sh").toString().replace("file://", ""), "open-browser", "https://github.com/" + root.git.githubRepo + "/issues/new"]
                  actionProc.running = true
                }
              }
            }
          }
        }
      }

      // 3D. Stashes View (Static elide with '...', Marquee on Hover)
      ListView {
        id: stashList
        anchors.fill: parent
        visible: root.gitSubTab === "stashes"
        clip: true
        spacing: Style.space(6)
        model: root.git.stashes || []

        delegate: Rectangle {
          id: stashRow
          width: stashList.width
          height: Style.space(46)
          radius: Style.cornerRadius
          color: stashRowMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)
          border.color: stashRowMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.3) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.1)
          border.width: 1

          MouseArea {
            id: stashRowMouse
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

            Text {
              text: "󰅖"
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              color: Color.urgent
            }

            ColumnLayout {
              spacing: 0
              Layout.fillWidth: true

              // Marquee Stash Message (Static elide with '...', Marquee on Hover)
              Item {
                id: stashMsgMarquee
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(18)
                clip: true

                readonly property string fullStashMsg: "stash@{" + modelData.index + "}: " + modelData.message
                readonly property bool isHovered: stashRowMouse.containsMouse
                readonly property bool isOverflowing: stashMsgText.implicitWidth > stashMsgMarquee.width

                onIsHoveredChanged: {
                  if (!isHovered) stashMsgText.x = 0
                }

                Text {
                  id: stashMsgText
                  text: stashMsgMarquee.fullStashMsg
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.weight: Font.Medium
                  color: Color.foreground
                  y: 0
                  width: stashMsgMarquee.isHovered ? implicitWidth : stashMsgMarquee.width
                  elide: stashMsgMarquee.isHovered ? Text.ElideNone : Text.ElideRight
                }

                SequentialAnimation {
                  id: stashMsgAnim
                  running: stashMsgMarquee.isHovered && stashMsgMarquee.isOverflowing
                  loops: Animation.Infinite

                  PauseAnimation { duration: 600 }
                  NumberAnimation {
                    target: stashMsgText
                    property: "x"
                    from: 0
                    to: -(stashMsgText.implicitWidth - stashMsgMarquee.width + Style.space(8))
                    duration: Math.max(1200, (stashMsgText.implicitWidth - stashMsgMarquee.width) * 30)
                    easing.type: Easing.Linear
                  }
                  PauseAnimation { duration: 1000 }
                  NumberAnimation {
                    target: stashMsgText
                    property: "x"
                    to: 0
                    duration: 400
                    easing.type: Easing.InOutQuad
                  }
                }
              }

              Text {
                text: modelData.date
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Color.muted
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
            }

            // Pop Stash Button
            Rectangle {
              width: popText.implicitWidth + Style.space(12)
              height: Style.space(24)
              radius: Style.cornerRadius
              color: popMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
              border.color: popMouse.containsMouse ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
              border.width: 1

              Text {
                id: popText
                anchors.centerIn: parent
                text: "Pop"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.weight: Font.Bold
                color: popMouse.containsMouse ? Color.accent : Color.foreground
              }

              MouseArea {
                id: popMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (actionProc) {
                    actionProc.command = [Qt.resolvedUrl("../helpers/devenv-action.sh").toString().replace("file://", ""), "git-stash-pop", root.git.repoPath, String(modelData.index)]
                    actionProc.running = true
                    Qt.callLater(root.onRefresh)
                  }
                }
              }

              PanelToolTip {
                visible: popMouse.containsMouse
                text: "Apply and drop stash@{" + modelData.index + "}"
              }
            }
          }

          PanelToolTip {
            visible: stashRowMouse.containsMouse && !popMouse.containsMouse
            text: "stash@{" + modelData.index + "}: " + modelData.message + "\n" + modelData.date
          }
        }

        // Empty Stashes state
        Text {
          anchors.centerIn: parent
          visible: !root.git.stashes || root.git.stashes.length === 0
          text: "󰅖 No git stashes saved"
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          color: Color.muted
        }
      }
    }
  }
}
