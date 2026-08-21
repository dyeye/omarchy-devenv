import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "dyeye.devenv"

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.open) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item && panelLoader.item.closeForPopoutSwitch) panelLoader.item.closeForPopoutSwitch()
  }

  readonly property var pData: (panelLoader.item && panelLoader.item.dataModel) ? panelLoader.item.dataModel : null
  readonly property int portCount: (pData && pData.ports) ? pData.ports.length : 0
  readonly property int dirtyCount: (pData && pData.git) ? pData.git.dirty : 0
  readonly property string projectName: (pData && pData.project && pData.project.name) ? pData.project.name : "DevEnv"

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: Style.bar.statusSlot
    tooltipText: "DevEnv (" + root.projectName + ")"

    contentItem: RowLayout {
      anchors.centerIn: parent
      spacing: Style.space(4)

      Text {
        text: "󱁐"
        font.family: Style.font.family
        font.pixelSize: Style.font.icon
        color: root.dirtyCount > 0 ? Color.accent : (root.bar ? root.bar.foreground : Color.foreground)
      }

      Text {
        visible: root.portCount > 0
        text: "󰒋" + root.portCount
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.weight: Font.DemiBold
        color: Color.accent
      }
    }

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton) {
        root.refresh()
      } else {
        root.togglePanel()
      }
    }
  }
}
