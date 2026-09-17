import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Ui
import qs.Commons
import "InputLayoutModel.js" as Model

BarWidget {
  id: root
  moduleName: "jordan.input-layout"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  property string layoutDescription: ""
  property string currentId: ""
  property string keyboardName: ""
  property string typedKeyboardName: ""
  property int keyboardCount: 0
  property bool keyboardUnresolved: false
  property var xkbTable: ({ "byId": {}, "byDescription": {} })
  property var currentIds: []
  readonly property string layoutLabel: Model.shortLabel(root.currentId, root.xkbTable)

  property var enabledIds: []
  property bool configLoaded: false
  property bool configPending: false
  readonly property var enabledLayouts: Model.rowsForLayouts(root.enabledIds, root.xkbTable)
  readonly property string configPath: Quickshell.env("HOME")
    + "/.local/state/omarchy/plugins/jordan.input-layout/config.json"

  property bool refreshPending: false
  property bool applyPending: false

  function isEnabled(id) {
    return root.enabledIds.indexOf(id) !== -1
  }

  function cycleNext() {
    if (root.bar) root.bar.run("hyprctl switchxkblayout all next")
    refreshTimer.restart()
  }

  function cyclePrev() {
    if (root.bar) root.bar.run("hyprctl switchxkblayout all prev")
    refreshTimer.restart()
  }

  function switchTo(id) {
    var index = root.enabledIds.indexOf(id)
    if (index >= 0 && root.bar) {
      root.bar.run("hyprctl switchxkblayout all " + index)
      refreshTimer.restart()
    }
  }

  function searchCatalog(query) {
    return Model.searchCatalog(query, root.enabledIds, root.xkbTable, 30)
  }

  function refresh() {
    if (devicesProc.running) {
      root.refreshPending = true
      return
    }
    root.refreshPending = false
    devicesProc.running = true
  }

  function applyConfig() {
    if (!root.configLoaded) return
    var wanted = Model.joined(root.enabledIds)
    if (wanted === "") return
    if (wanted === Model.joined(root.currentIds)) {
      root.applyPending = false
      return
    }
    if (applyProc.running) {
      root.applyPending = true
      return
    }
    var hypr = Model.toHyprland(root.enabledIds)
    applyProc.command = ["hyprctl", "eval",
      'hl.config({ input = { kb_layout = "' + hypr.layout + '", kb_variant = "' + hypr.variant + '" } })']
    applyProc.running = true
  }

  function setLayoutEnabled(id, on) {
    if (!root.configLoaded) return
    var list = root.enabledIds.slice()
    var index = list.indexOf(id)
    if (on) {
      if (index < 0) {
        list.push(id)
        root.enabledIds = list
        persistConfig(list)
      }
    } else {
      if (index < 0) return
      if (list.length <= 1) return
      list.splice(index, 1)
      root.enabledIds = list
      persistConfig(list)
    }
  }

  function persistConfig(list) {
    root.applyConfig()
    configFile.setText(JSON.stringify({ "version": 1, "enabled": list }))
  }

  function loadConfig(text) {
    try {
      var payload = JSON.parse(String(text || ""))
      var list = payload && payload.enabled
      if (!Array.isArray(list)) throw new Error("bad shape")
      var valid = list.filter(function (id) {
        return typeof id === "string" && id.length > 0
      })
      if (valid.length === 0) throw new Error("empty")
      root.enabledIds = valid
      root.configLoaded = true
      Qt.callLater(root.applyConfig)
      return
    } catch (error) {
      if (root.currentIds.length > 0) root.initConfig()
      else root.configPending = true
    }
  }

  function initConfig() {
    if (root.configLoaded) return
    var seed = root.currentIds.slice()
    if (seed.length === 0) seed = ["us"]
    root.enabledIds = seed
    root.configLoaded = true
    configFile.setText(JSON.stringify({ "version": 1, "enabled": seed }))
    Qt.callLater(root.applyConfig)
  }

  function typedKeyboards(list) {
    return list.filter(function (keyboard) {
      return Model.isTypedKeyboard(keyboard.name)
    })
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = Qt.binding(function() { return root.bar })
    target.settings = Qt.binding(function() { return root.settings })
    target.anchorItem = button
    target.hostWidget = root
  }

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

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

  Component.onCompleted: {
    briefsProc.running = true
    root.refresh()
    ensureDirProc.running = true
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.layoutLabel
    fontSize: Style.font.caption
    horizontalMargin: 6
    tooltipText: root.layoutDescription ? root.layoutDescription : "Input layout"
    onPressed: function(button) {
      if (button === Qt.LeftButton) root.togglePanel()
      else if (button === Qt.MiddleButton) root.cyclePrev()
      else root.cycleNext()
    }
    onWheelMoved: function(delta) {
      if (delta > 0) root.cycleNext()
      else root.cyclePrev()
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (!event || !event.name) return
      var name = String(event.name)
      if (name === "activelayout") {
        var named = Model.eventKeyboardName(event)
        if (named) root.typedKeyboardName = named
      }
      if (name.indexOf("activelayout") !== -1 || name === "configreloaded") root.refresh()
    }
  }

  Process {
    id: ensureDirProc
    command: ["mkdir", "-p",
      Quickshell.env("HOME") + "/.local/state/omarchy/plugins/jordan.input-layout"]
    onExited: configFile.reload()
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    onLoaded: root.loadConfig(text())
    onFileChanged: reload()
    onLoadFailed: {
      if (root.currentIds.length > 0) root.initConfig()
      else root.configPending = true
    }
  }

  Timer {
    interval: 10000
    running: !root.keyboardName || root.keyboardUnresolved || root.keyboardCount > 1
    repeat: true
    onTriggered: root.refresh()
  }

  Timer {
    id: refreshTimer
    interval: 600
    onTriggered: root.refresh()
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: devicesProc
    command: ["hyprctl", "-j", "devices"]
    onRunningChanged: {
      if (running) return
      if (root.refreshPending) root.refresh()
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var listed
        try {
          listed = JSON.parse(text || "{}").keyboards
        } catch (error) {
          return
        }
        if (!Array.isArray(listed)) {
          root.keyboardUnresolved = true
          return
        }

        var typed = root.typedKeyboards(listed)
        var keyboard = Model.selectKeyboard(typed, root.typedKeyboardName)
        if (!keyboard || !keyboard.active_keymap) {
          root.keyboardUnresolved = true
          if (typed.length === 0) {
            root.layoutDescription = ""
            root.keyboardName = ""
            root.currentId = ""
            root.currentIds = []
          }
          return
        }

        var ids = Model.parseIds(keyboard.layout, keyboard.variant)
        var index = keyboard.active_layout_index || 0
        root.keyboardUnresolved = false
        root.keyboardCount = typed.length
        root.keyboardName = String(keyboard.name || "")
        root.currentIds = ids
        root.currentId = ids[index] || ids[0] || ""
        root.layoutDescription = String(keyboard.active_keymap || "")
        if (root.configPending && !root.configLoaded) {
          root.configPending = false
          root.initConfig()
        } else {
          root.applyConfig()
        }
      }
    }
  }

  Process {
    id: briefsProc
    command: ["xkbcli", "list", "--load-exotic"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.xkbTable = Model.layoutTable(text)
    }
  }

  Process {
    id: applyProc
    command: []
    onExited: {
      if (root.applyPending) {
        root.applyPending = false
        root.applyConfig()
      }
      root.refresh()
    }
  }
}
