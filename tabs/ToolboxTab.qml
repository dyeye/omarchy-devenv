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

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.space(8)

    // Sub-navigation pills
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(6)

      // JSON tool pill
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

      // Timestamp tool pill
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

      // Base64 tool pill
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(28)
        radius: Style.cornerRadius
        color: root.activeTool === "base64" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)
        border.color: root.activeTool === "base64" ? Color.accent : "transparent"
        border.width: 1
        Text {
          anchors.centerIn: parent
          text: "󰮔 Base64"
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

      // UUID tool pill
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(28)
        radius: Style.cornerRadius
        color: root.activeTool === "uuid" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.05)
        border.color: root.activeTool === "uuid" ? Color.accent : "transparent"
        border.width: 1
        Text {
          anchors.centerIn: parent
          text: "󰌠 UUID"
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

    // 1. JSON Tool View
    ColumnLayout {
      visible: root.activeTool === "json"
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Style.space(6)

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)

        // Format Button
        Rectangle {
          Layout.preferredWidth: fmtText.implicitWidth + Style.space(14)
          Layout.preferredHeight: Style.space(26)
          radius: Style.cornerRadius
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
          RowLayout {
            id: fmtText
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text { text: "󰘳"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
            Text { text: "Format (2 spaces)"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
          }
          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              try {
                jsonArea.text = Model.formatJson(jsonArea.text, 2)
              } catch (e) {
                jsonStatus.text = "Error: Invalid JSON"
              }
            }
          }
        }

        // Minify Button
        Rectangle {
          Layout.preferredWidth: minText.implicitWidth + Style.space(14)
          Layout.preferredHeight: Style.space(26)
          radius: Style.cornerRadius
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
          RowLayout {
            id: minText
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text { text: "󰚌"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
            Text { text: "Minify"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
          }
          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              try {
                jsonArea.text = Model.minifyJson(jsonArea.text)
              } catch (e) {
                jsonStatus.text = "Error: Invalid JSON"
              }
            }
          }
        }

        Item { Layout.fillWidth: true }

        // Copy Button
        Rectangle {
          Layout.preferredWidth: cpText.implicitWidth + Style.space(12)
          Layout.preferredHeight: Style.space(26)
          radius: Style.cornerRadius
          color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
          RowLayout {
            id: cpText
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text { text: "󰆏"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.accent }
            Text { text: "Copy"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.accent }
          }
          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.clipboardText = jsonArea.text
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
            id: jsonArea
            placeholderText: "Paste JSON string here..."
            font.family: "Monospace"
            font.pixelSize: Style.font.caption
            color: Color.foreground
            wrapMode: TextEdit.WrapAnywhere
            background: Item {}
          }
        }
      }

      Text {
        id: jsonStatus
        text: ""
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        color: Color.urgent
      }
    }

    // 2. Timestamp Tool View
    ColumnLayout {
      visible: root.activeTool === "timestamp"
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Style.space(10)

      Text {
        text: "󱁤 Epoch / UNIX Timestamp Converter"
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.weight: Font.DemiBold
        color: Color.muted
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(38)
        radius: Style.cornerRadius
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)
        border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.margins: Style.space(6)
          TextField {
            id: timeInput
            Layout.fillWidth: true
            placeholderText: "e.g. 1724250000 or now"
            text: String(Math.floor(Date.now() / 1000))
            font.family: "Monospace"
            font.pixelSize: Style.font.bodySmall
            color: Color.foreground
            background: Item {}
          }
          Rectangle {
            width: Style.space(56)
            height: Style.space(26)
            radius: Style.cornerRadius
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.1)
            Text { anchors.centerIn: parent; text: "Now"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: timeInput.text = String(Math.floor(Date.now() / 1000))
            }
          }
        }
      }

      // Result card
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(60)
        radius: Style.cornerRadius
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
        border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.margins: Style.space(10)
          ColumnLayout {
            spacing: Style.space(2)
            Text { text: "Converted Date:"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.muted }
            Text {
              text: Model.timestampToDate(timeInput.text)
              font.family: "Monospace"
              font.pixelSize: Style.font.bodySmall
              font.weight: Font.Bold
              color: Color.accent
            }
          }
          Item { Layout.fillWidth: true }
          Rectangle {
            width: Style.space(28)
            height: Style.space(28)
            radius: Style.cornerRadius
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.1)
            Text { anchors.centerIn: parent; text: "󰆏"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: Quickshell.clipboardText = Model.timestampToDate(timeInput.text)
            }
          }
        }
      }

      Item { Layout.fillHeight: true }
    }

    // 3. Base64 Tool View
    ColumnLayout {
      visible: root.activeTool === "base64"
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Style.space(6)

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)

        Rectangle {
          Layout.preferredWidth: encBtn.implicitWidth + Style.space(12)
          Layout.preferredHeight: Style.space(26)
          radius: Style.cornerRadius
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
          Text { id: encBtn; anchors.centerIn: parent; text: "Encode Base64"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: b64Area.text = Model.base64Encode(b64Area.text)
          }
        }

        Rectangle {
          Layout.preferredWidth: decBtn.implicitWidth + Style.space(12)
          Layout.preferredHeight: Style.space(26)
          radius: Style.cornerRadius
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
          Text { id: decBtn; anchors.centerIn: parent; text: "Decode Base64"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: b64Area.text = Model.base64Decode(b64Area.text)
          }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
          Layout.preferredWidth: cpB64.implicitWidth + Style.space(12)
          Layout.preferredHeight: Style.space(26)
          radius: Style.cornerRadius
          color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
          RowLayout {
            id: cpB64
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text { text: "󰆏"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.accent }
            Text { text: "Copy"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.accent }
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.clipboardText = b64Area.text
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

    // 4. UUID Tool View
    ColumnLayout {
      visible: root.activeTool === "uuid"
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Style.space(10)

      property string currentUuid: Model.generateUuid()

      Text {
        text: "󰌠 UUID v4 Generator"
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.weight: Font.DemiBold
        color: Color.muted
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(56)
        radius: Style.cornerRadius
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
        border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.margins: Style.space(10)

          Text {
            text: parent.parent.currentUuid
            font.family: "Monospace"
            font.pixelSize: Style.font.body
            font.weight: Font.Bold
            color: Color.accent
          }

          Item { Layout.fillWidth: true }

          // Generate New
          Rectangle {
            width: Style.space(30)
            height: Style.space(30)
            radius: Style.cornerRadius
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.1)
            Text { anchors.centerIn: parent; text: "󰑐"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.foreground }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: parent.parent.parent.parent.currentUuid = Model.generateUuid()
            }
          }

          // Copy UUID
          Rectangle {
            width: Style.space(30)
            height: Style.space(30)
            radius: Style.cornerRadius
            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)
            Text { anchors.centerIn: parent; text: "󰆏"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: Color.accent }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: Quickshell.clipboardText = parent.parent.parent.parent.currentUuid
            }
          }
        }
      }

      Item { Layout.fillHeight: true }
    }
  }
}
