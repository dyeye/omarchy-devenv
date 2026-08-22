import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "../Model.js" as Model

Item {
  id: root

  property string activeTool: "json" // "json" | "timestamp" | "base64" | "uuid"

  // Toast / Feedback message
  property string toastMessage: ""
  Timer {
    id: toastTimer
    interval: 2000
    repeat: false
    onTriggered: root.toastMessage = ""
  }

  function showToast(msg) {
    root.toastMessage = msg
    toastTimer.restart()
  }

  function copyToClipboard(text) {
    if (text === undefined || text === null) return
    Quickshell.execDetached(["bash", "-c", "printf %s \"$1\" | wl-copy", "_", String(text)])
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.space(8)

    // 1. Sub-navigation pills
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(6)

      // JSON pill
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(28)
        radius: Style.cornerRadius
        color: root.activeTool === "json" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)
        border.color: root.activeTool === "json" ? Color.accent : "transparent"
        border.width: 1
        Text {
          anchors.centerIn: parent
          text: "{ } JSON"
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.weight: root.activeTool === "json" ? Font.Bold : Font.Normal
          color: root.activeTool === "json" ? Color.accent : Color.foreground
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.activeTool = "json"
        }
      }

      // Timestamp pill
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(28)
        radius: Style.cornerRadius
        color: root.activeTool === "timestamp" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)
        border.color: root.activeTool === "timestamp" ? Color.accent : "transparent"
        border.width: 1
        Text {
          anchors.centerIn: parent
          text: "󱁤 Time"
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.weight: root.activeTool === "timestamp" ? Font.Bold : Font.Normal
          color: root.activeTool === "timestamp" ? Color.accent : Color.foreground
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.activeTool = "timestamp"
        }
      }

      // Base64 pill
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(28)
        radius: Style.cornerRadius
        color: root.activeTool === "base64" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)
        border.color: root.activeTool === "base64" ? Color.accent : "transparent"
        border.width: 1
        Text {
          anchors.centerIn: parent
          text: "󰻠 Base64"
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.weight: root.activeTool === "base64" ? Font.Bold : Font.Normal
          color: root.activeTool === "base64" ? Color.accent : Color.foreground
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.activeTool = "base64"
        }
      }

      // UUID pill
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(28)
        radius: Style.cornerRadius
        color: root.activeTool === "uuid" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)
        border.color: root.activeTool === "uuid" ? Color.accent : "transparent"
        border.width: 1
        Text {
          anchors.centerIn: parent
          text: "󰌠 UUID Gen"
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.weight: root.activeTool === "uuid" ? Font.Bold : Font.Normal
          color: root.activeTool === "uuid" ? Color.accent : Color.foreground
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.activeTool = "uuid"
        }
      }
    }

    // 2. Global Toast Feedback (when copying or performing actions)
    Rectangle {
      visible: root.toastMessage !== ""
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(22)
      radius: Style.cornerRadius - 2
      color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
      border.color: Color.accent
      border.width: 1

      RowLayout {
        anchors.centerIn: parent
        spacing: Style.space(6)
        Text {
          text: "󰄳"
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          color: Color.accent
        }
        Text {
          text: root.toastMessage
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.weight: Font.DemiBold
          color: Color.accent
        }
      }
    }

    // ---------------------------------------------------------------- 1. JSON Tool View
    ColumnLayout {
      visible: root.activeTool === "json"
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Style.space(6)

      // Actions Toolbar
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)

        // Format 2 spaces
        Rectangle {
          Layout.preferredWidth: fmtText2.implicitWidth + Style.space(12)
          Layout.preferredHeight: Style.space(26)
          radius: Style.cornerRadius
          color: fmt2Mouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
          RowLayout {
            id: fmtText2
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text { text: "󰉢"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
            Text { text: "Format (2 sp)"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
          }
          MouseArea {
            id: fmt2Mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              try {
                jsonArea.text = Model.formatJson(jsonArea.text, 2)
                root.showToast("Formatted with 2 spaces")
              } catch (e) {
                root.showToast("Error: " + e.message)
              }
            }
          }
        }

        // Format 4 spaces
        Rectangle {
          Layout.preferredWidth: fmtText4.implicitWidth + Style.space(12)
          Layout.preferredHeight: Style.space(26)
          radius: Style.cornerRadius
          color: fmt4Mouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
          RowLayout {
            id: fmtText4
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text { text: "󰉢"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
            Text { text: "4 sp"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
          }
          MouseArea {
            id: fmt4Mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              try {
                jsonArea.text = Model.formatJson(jsonArea.text, 4)
                root.showToast("Formatted with 4 spaces")
              } catch (e) {
                root.showToast("Error: " + e.message)
              }
            }
          }
        }

        // Minify
        Rectangle {
          Layout.preferredWidth: minText.implicitWidth + Style.space(12)
          Layout.preferredHeight: Style.space(26)
          radius: Style.cornerRadius
          color: minMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
          RowLayout {
            id: minText
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text { text: ""; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
            Text { text: "Minify"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
          }
          MouseArea {
            id: minMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              try {
                jsonArea.text = Model.minifyJson(jsonArea.text)
                root.showToast("Minified JSON")
              } catch (e) {
                root.showToast("Error: " + e.message)
              }
            }
          }
        }

        // Sample
        Rectangle {
          Layout.preferredWidth: smpText.implicitWidth + Style.space(12)
          Layout.preferredHeight: Style.space(26)
          radius: Style.cornerRadius
          color: smpMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
          RowLayout {
            id: smpText
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text { text: "󰈙"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
            Text { text: "Sample"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
          }
          MouseArea {
            id: smpMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              jsonArea.text = '{\n  "status": "success",\n  "code": 200,\n  "data": {\n    "id": "usr_9481",\n    "name": "DevEnv User",\n    "active": true,\n    "tags": ["omarchy", "developer", "quick-tools"]\n  }\n}'
            }
          }
        }

        Item { Layout.fillWidth: true }

        // Clear
        Rectangle {
          Layout.preferredWidth: clrText.implicitWidth + Style.space(12)
          Layout.preferredHeight: Style.space(26)
          radius: Style.cornerRadius
          color: clrMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.2) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
          RowLayout {
            id: clrText
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text { text: "󰅖"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
            Text { text: "Clear"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
          }
          MouseArea {
            id: clrMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: jsonArea.text = ""
          }
        }

        // Copy
        Rectangle {
          Layout.preferredWidth: cpText.implicitWidth + Style.space(12)
          Layout.preferredHeight: Style.space(26)
          radius: Style.cornerRadius
          color: cpMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
          RowLayout {
            id: cpText
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text { text: "󰆏"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.accent }
            Text { text: "Copy"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.accent }
          }
          MouseArea {
            id: cpMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.copyToClipboard(jsonArea.text)
              root.showToast("Copied JSON to clipboard")
            }
          }
        }
      }

      // JSON Text Area
      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Style.cornerRadius
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)
        border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
        border.width: 1

        ScrollView {
          anchors.fill: parent
          anchors.margins: Style.space(6)

          TextArea {
            id: jsonArea
            placeholderText: "Paste or type JSON string here..."
            font.family: "Monospace"
            font.pixelSize: Style.font.caption
            color: Color.foreground
            wrapMode: TextEdit.WrapAnywhere
            background: Item {}
          }
        }
      }
    }

    // ---------------------------------------------------------------- 2. Timestamp Tool View (100% Live Dashboard)
    ColumnLayout {
      id: timeDashboard
      visible: root.activeTool === "timestamp"
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Style.space(8)

      property var now: new Date()

      Timer {
        id: liveClockTimer
        interval: 1000
        running: root.activeTool === "timestamp"
        repeat: true
        onTriggered: timeDashboard.now = new Date()
      }

      // Live Formats Container Card
      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Style.cornerRadius
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)
        border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
        border.width: 1

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.space(12)
          spacing: Style.space(10)

          // 1. Unix Epoch Seconds (Hero)
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)
            ColumnLayout {
              spacing: 0
              Layout.fillWidth: true
              Text { text: "Unix Timestamp (Seconds):"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.muted }
              Text {
                text: String(Math.floor(timeDashboard.now.getTime() / 1000))
                textFormat: Text.PlainText
                font.family: "Monospace"
                font.pixelSize: Style.font.body
                font.weight: Font.Bold
                color: Color.accent
              }
            }
            Rectangle {
              width: Style.space(28)
              height: Style.space(28)
              radius: Style.cornerRadius - 2
              color: secCpMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
              Text { anchors.centerIn: parent; text: "󰆏"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
              MouseArea {
                id: secCpMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.copyToClipboard(String(Math.floor(timeDashboard.now.getTime() / 1000)))
                  root.showToast("Copied Unix Epoch (seconds)")
                }
              }
              PanelToolTip {
                visible: secCpMouse.containsMouse
                text: "Copy Unix seconds"
              }
            }
          }

          // Divider
          Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) }

          // 2. Unix Epoch Milliseconds
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)
            ColumnLayout {
              spacing: 0
              Layout.fillWidth: true
              Text { text: "Unix Timestamp (Milliseconds):"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.muted }
              Text {
                text: String(timeDashboard.now.getTime())
                textFormat: Text.PlainText
                font.family: "Monospace"
                font.pixelSize: Style.font.bodySmall
                font.weight: Font.Bold
                color: Color.foreground
              }
            }
            Rectangle {
              width: Style.space(28)
              height: Style.space(28)
              radius: Style.cornerRadius - 2
              color: msCpMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
              Text { anchors.centerIn: parent; text: "󰆏"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
              MouseArea {
                id: msCpMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.copyToClipboard(String(timeDashboard.now.getTime()))
                  root.showToast("Copied Unix Epoch (ms)")
                }
              }
              PanelToolTip {
                visible: msCpMouse.containsMouse
                text: "Copy Unix milliseconds"
              }
            }
          }

          // Divider
          Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) }

          // 3. UTC Date (ISO 8601)
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)
            ColumnLayout {
              spacing: 0
              Layout.fillWidth: true
              Text { text: "UTC (ISO 8601):"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.muted }
              Text {
                text: timeDashboard.now.toISOString().replace("T", " ").replace("Z", " UTC")
                textFormat: Text.PlainText
                font.family: "Monospace"
                font.pixelSize: Style.font.bodySmall
                font.weight: Font.DemiBold
                color: Color.foreground
              }
            }
            Rectangle {
              width: Style.space(28)
              height: Style.space(28)
              radius: Style.cornerRadius - 2
              color: utcCpMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
              Text { anchors.centerIn: parent; text: "󰆏"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
              MouseArea {
                id: utcCpMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.copyToClipboard(timeDashboard.now.toISOString().replace("T", " ").replace("Z", " UTC"))
                  root.showToast("Copied UTC time")
                }
              }
              PanelToolTip {
                visible: utcCpMouse.containsMouse
                text: "Copy UTC date string"
              }
            }
          }

          // Divider
          Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) }

          // 4. Local Formatted Time
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)
            ColumnLayout {
              spacing: 0
              Layout.fillWidth: true
              Text { text: "Local Time:"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.muted }
              Text {
                text: timeDashboard.now.toLocaleString()
                textFormat: Text.PlainText
                font.family: "Monospace"
                font.pixelSize: Style.font.bodySmall
                color: Color.foreground
              }
            }
            Rectangle {
              width: Style.space(28)
              height: Style.space(28)
              radius: Style.cornerRadius - 2
              color: locCpMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
              Text { anchors.centerIn: parent; text: "󰆏"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
              MouseArea {
                id: locCpMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.copyToClipboard(timeDashboard.now.toLocaleString())
                  root.showToast("Copied Local date string")
                }
              }
              PanelToolTip {
                visible: locCpMouse.containsMouse
                text: "Copy Local time string"
              }
            }
          }

          // Divider
          Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) }

          // 5. Full ISO 8601 String
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)
            ColumnLayout {
              spacing: 0
              Layout.fillWidth: true
              Text { text: "ISO 8601 Full String:"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.muted }
              Text {
                text: timeDashboard.now.toISOString()
                textFormat: Text.PlainText
                font.family: "Monospace"
                font.pixelSize: Style.font.caption
                color: Color.muted
              }
            }
            Rectangle {
              width: Style.space(28)
              height: Style.space(28)
              radius: Style.cornerRadius - 2
              color: isoCpMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
              Text { anchors.centerIn: parent; text: "󰆏"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
              MouseArea {
                id: isoCpMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.copyToClipboard(timeDashboard.now.toISOString())
                  root.showToast("Copied ISO 8601 string")
                }
              }
              PanelToolTip {
                visible: isoCpMouse.containsMouse
                text: "Copy ISO 8601 string"
              }
            }
          }

          Item { Layout.fillHeight: true }
        }
      }
    }

    // ---------------------------------------------------------------- 3. Base64 Tool View
    ColumnLayout {
      id: b64ToolView
      visible: root.activeTool === "base64"
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Style.space(6)

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)

        // Encode Button
        Rectangle {
          Layout.preferredWidth: encBtn.implicitWidth + Style.space(14)
          Layout.preferredHeight: Style.space(26)
          radius: Style.cornerRadius
          color: encMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
          Text { id: encBtn; anchors.centerIn: parent; text: "󰐊 Encode Base64"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
          MouseArea {
            id: encMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              b64Area.text = Model.base64Encode(b64Area.text)
              root.showToast("Base64 Encoded")
            }
          }
        }

        // Decode Button
        Rectangle {
          Layout.preferredWidth: decBtn.implicitWidth + Style.space(14)
          Layout.preferredHeight: Style.space(26)
          radius: Style.cornerRadius
          color: decMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
          Text { id: decBtn; anchors.centerIn: parent; text: "󰐊 Decode Base64"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
          MouseArea {
            id: decMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              b64Area.text = Model.base64Decode(b64Area.text)
              root.showToast("Base64 Decoded")
            }
          }
        }

        Item { Layout.fillWidth: true }

        // Clear Button
        Rectangle {
          Layout.preferredWidth: clrB64.implicitWidth + Style.space(12)
          Layout.preferredHeight: Style.space(26)
          radius: Style.cornerRadius
          color: clrB64Mouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.2) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
          RowLayout {
            id: clrB64
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text { text: "󰅖"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
            Text { text: "Clear"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
          }
          MouseArea {
            id: clrB64Mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: b64Area.text = ""
          }
        }

        // Copy Button
        Rectangle {
          Layout.preferredWidth: cpB64.implicitWidth + Style.space(12)
          Layout.preferredHeight: Style.space(26)
          radius: Style.cornerRadius
          color: cpB64Mouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
          RowLayout {
            id: cpB64
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text { text: "󰆏"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.accent }
            Text { text: "Copy"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.accent }
          }
          MouseArea {
            id: cpB64Mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.copyToClipboard(b64Area.text)
              root.showToast("Copied text to clipboard")
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Style.cornerRadius
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)
        border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
        border.width: 1

        ScrollView {
          anchors.fill: parent
          anchors.margins: Style.space(6)
          TextArea {
            id: b64Area
            placeholderText: "Type or paste text to encode/decode..."
            font.family: "Monospace"
            font.pixelSize: Style.font.caption
            color: Color.foreground
            wrapMode: TextEdit.WrapAnywhere
            background: Item {}
          }
        }
      }
    }

    // ---------------------------------------------------------------- 4. UUID Tool View (Supercharged)
    ColumnLayout {
      id: uuidToolView
      visible: root.activeTool === "uuid"
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Style.space(8)

      property string uuidVersion: "v4" // "v4" | "v7"
      property bool uppercase: false
      property bool hyphens: true
      property int count: 1
      property var generatedList: []

      Component.onCompleted: uuidToolView.regenerate()

      function regenerate() {
        uuidToolView.generatedList = Model.generateUuids({
          version: uuidToolView.uuidVersion,
          uppercase: uuidToolView.uppercase,
          hyphens: uuidToolView.hyphens,
          count: uuidToolView.count
        })
      }

      // Row 1: Version & Format Options
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)

        // Version: v4
        Rectangle {
          Layout.preferredWidth: v4Btn.implicitWidth + Style.space(12)
          Layout.preferredHeight: Style.space(26)
          radius: Style.cornerRadius
          color: uuidToolView.uuidVersion === "v4" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
          border.color: uuidToolView.uuidVersion === "v4" ? Color.accent : "transparent"
          border.width: 1
          Text {
            id: v4Btn
            anchors.centerIn: parent
            text: "v4 (Random)"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.weight: uuidToolView.uuidVersion === "v4" ? Font.Bold : Font.Normal
            color: uuidToolView.uuidVersion === "v4" ? Color.accent : Color.foreground
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              uuidToolView.uuidVersion = "v4"
              uuidToolView.regenerate()
            }
          }
        }

        // Version: v7 (Time-Ordered)
        Rectangle {
          Layout.preferredWidth: v7Btn.implicitWidth + Style.space(12)
          Layout.preferredHeight: Style.space(26)
          radius: Style.cornerRadius
          color: uuidToolView.uuidVersion === "v7" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
          border.color: uuidToolView.uuidVersion === "v7" ? Color.accent : "transparent"
          border.width: 1
          Text {
            id: v7Btn
            anchors.centerIn: parent
            text: "v7 (Time)"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.weight: uuidToolView.uuidVersion === "v7" ? Font.Bold : Font.Normal
            color: uuidToolView.uuidVersion === "v7" ? Color.accent : Color.foreground
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              uuidToolView.uuidVersion = "v7"
              uuidToolView.regenerate()
            }
          }
        }

        Item { Layout.fillWidth: true }

        // Uppercase Toggle
        Rectangle {
          Layout.preferredWidth: ucBtn.implicitWidth + Style.space(10)
          Layout.preferredHeight: Style.space(26)
          radius: Style.cornerRadius
          color: uuidToolView.uppercase ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
          border.color: uuidToolView.uppercase ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.1)
          border.width: 1
          Text {
            id: ucBtn
            anchors.centerIn: parent
            text: "aA UPPER"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            color: uuidToolView.uppercase ? Color.accent : Color.foreground
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              uuidToolView.uppercase = !uuidToolView.uppercase
              uuidToolView.regenerate()
            }
          }
        }

        // Hyphens Toggle
        Rectangle {
          Layout.preferredWidth: hypBtn.implicitWidth + Style.space(10)
          Layout.preferredHeight: Style.space(26)
          radius: Style.cornerRadius
          color: uuidToolView.hyphens ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
          border.color: uuidToolView.hyphens ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.1)
          border.width: 1
          Text {
            id: hypBtn
            anchors.centerIn: parent
            text: "- Hyphens"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            color: uuidToolView.hyphens ? Color.accent : Color.foreground
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              uuidToolView.hyphens = !uuidToolView.hyphens
              uuidToolView.regenerate()
            }
          }
        }
      }

      // Row 2: Batch Count & Action Bar
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)

        // Batch Count Selector
        RowLayout {
          spacing: Style.space(3)
          Text {
            text: "Count:"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            color: Color.muted
          }
          Repeater {
            model: [1, 5, 10]
            delegate: Rectangle {
              width: Style.space(28)
              height: Style.space(26)
              radius: Style.cornerRadius - 2
              color: uuidToolView.count === modelData ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
              border.color: uuidToolView.count === modelData ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.1)
              border.width: 1
              Text {
                anchors.centerIn: parent
                text: modelData + "x"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.weight: uuidToolView.count === modelData ? Font.Bold : Font.Normal
                color: uuidToolView.count === modelData ? Color.accent : Color.foreground
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  uuidToolView.count = modelData
                  uuidToolView.regenerate()
                }
              }
            }
          }
        }

        Item { Layout.fillWidth: true }

        // Regenerate Button
        Rectangle {
          Layout.preferredWidth: genBtnText.implicitWidth + Style.space(14)
          Layout.preferredHeight: Style.space(26)
          radius: Style.cornerRadius
          color: genMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18)
          border.color: Color.accent
          border.width: 1

          RowLayout {
            id: genBtnText
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text { text: "󰑐"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.accent }
            Text { text: "Generate"; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.Bold; color: Color.accent }
          }
          MouseArea {
            id: genMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              uuidToolView.regenerate()
              root.showToast("Generated new " + uuidToolView.uuidVersion.toUpperCase())
            }
          }
        }

        // Copy All Button
        Rectangle {
          Layout.preferredWidth: cpAllText.implicitWidth + Style.space(12)
          Layout.preferredHeight: Style.space(26)
          radius: Style.cornerRadius
          color: cpAllMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.18) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
          border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
          border.width: 1

          RowLayout {
            id: cpAllText
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text { text: "󰆏"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
            Text { text: uuidToolView.count > 1 ? ("Copy All (" + uuidToolView.count + ")") : "Copy"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
          }
          MouseArea {
            id: cpAllMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var all = uuidToolView.generatedList.join("\n")
              root.copyToClipboard(all)
              root.showToast("Copied " + uuidToolView.generatedList.length + " UUID(s) to clipboard")
            }
          }
        }
      }

      // UUID Output List Container
      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Style.cornerRadius
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)
        border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
        border.width: 1

        ListView {
          id: uuidListView
          anchors.fill: parent
          anchors.margins: Style.space(8)
          clip: true
          spacing: Style.space(6)
          model: uuidToolView.generatedList

          delegate: Rectangle {
            width: uuidListView.width
            height: Style.space(38)
            radius: Style.cornerRadius - 2
            color: itemMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)
            border.color: itemMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
            border.width: 1

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(8)

              // Index badge if count > 1
              Rectangle {
                visible: uuidToolView.count > 1
                width: Style.space(20)
                height: Style.space(20)
                radius: Style.cornerRadius - 3
                color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                Text {
                  anchors.centerIn: parent
                  text: String(index + 1)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  color: Color.muted
                }
              }

              // UUID Text
              Text {
                text: modelData
                textFormat: Text.PlainText
                font.family: "Monospace"
                font.pixelSize: Style.font.bodySmall
                font.weight: Font.Bold
                color: itemMouse.containsMouse ? Color.accent : Color.foreground
                Layout.fillWidth: true
                elide: Text.ElideMiddle
              }

              // Individual 1-Click Copy
              Rectangle {
                width: Style.space(26)
                height: Style.space(26)
                radius: Style.cornerRadius - 2
                color: indCpMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                Text { anchors.centerIn: parent; text: "󰆏"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
                MouseArea {
                  id: indCpMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.copyToClipboard(modelData)
                    root.showToast("Copied: " + modelData)
                  }
                }
                PanelToolTip {
                  visible: indCpMouse.containsMouse
                  text: "Copy this UUID"
                }
              }
            }

            MouseArea {
              id: itemMouse
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.LeftButton
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.copyToClipboard(modelData)
                root.showToast("Copied: " + modelData)
              }
            }
          }
        }
      }
    }
  }
}
