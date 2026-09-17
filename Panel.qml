import QtQuick
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "jordan.input-layout"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property bool editing: false

  readonly property var barIdentity: hostWidget || root
  readonly property color foregroundColor: bar ? bar.barForeground : Color.foreground
  readonly property color mutedColor: Util.alpha(foregroundColor, 0.6)
  readonly property color faintColor: Util.alpha(foregroundColor, 0.38)
  readonly property color accentColor: Color.accent

  readonly property var enabled: hostWidget ? hostWidget.enabledLayouts : []
  readonly property string currentId: hostWidget ? hostWidget.currentId : ""
  readonly property int rowHeight: Math.max(30, Style.spacing.controlHeight)
  readonly property int listCap: Style.space(320)
  readonly property int manageListHeight: Math.min(root.enabled.length * root.rowHeight, root.listCap)

  property string searchText: ""
  readonly property var filteredCatalog: {
    var q = root.searchText
    var host = root.hostWidget
    if (!host || q.length === 0) return []
    var _ = host.enabledIds
    return host.searchCatalog(q)
  }
  readonly property int searchResultsHeight: Math.min(root.filteredCatalog.length * root.rowHeight, root.listCap)

  function open() {
    root.editing = false
    controller.show()
  }

  function close() {
    controller.hide()
  }

  function closeForPopoutSwitch() {
    popoutSwitchClosing = true
    close()
    Qt.callLater(function() { popoutSwitchClosing = false })
  }

  function toggle() {
    if (opened) close()
    else open()
  }

  function selectLayout(id) {
    if (hostWidget) hostWidget.switchTo(id)
    close()
  }

  function toggleLayout(id) {
    if (hostWidget) hostWidget.setLayoutEnabled(id, !hostWidget.isEnabled(id))
  }

  function addLayout(id) {
    if (hostWidget) hostWidget.setLayoutEnabled(id, true)
    root.searchText = ""
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
          root.bar.switchPanelFrom(root.barIdentity, direction)
      }

      Column {
        id: contentColumn
        width: parent.width
        spacing: Style.space(14)

        Item {
          width: parent.width
          height: Math.max(Style.font.title + Style.spacing.xxs, gearButton.height)

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.editing ? "MANAGE LAYOUTS" : "INPUT LAYOUT"
            color: root.foregroundColor
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
          }

          PanelActionButton {
            id: gearButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰒓"
            tooltipText: root.editing ? "Back to layouts" : "Manage layouts"
            foreground: root.editing ? root.accentColor : root.foregroundColor
            hoverColor: root.accentColor
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            fontSize: Style.font.subtitle
            size: Style.space(26)
            onClicked: root.editing = !root.editing
          }
        }

        PanelSeparator {
          width: parent.width
          foreground: root.foregroundColor
        }

        Column {
          width: parent.width
          spacing: Style.spacing.controlGap
          visible: !root.editing

          PanelSectionHeader {
            text: "ACTIVE"
            foreground: root.foregroundColor
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          }

          Column {
            width: parent.width
            spacing: Style.spacing.xxs
            visible: root.enabled.length > 0

            Repeater {
              model: root.enabled

              delegate: Rectangle {
                required property var modelData
                width: parent.width
                height: root.rowHeight
                radius: Style.cornerRadius

                readonly property bool isCurrent: modelData.id === root.currentId
                readonly property bool hot: mouse.containsMouse

                color: isCurrent
                  ? Style.selectedAccentFill
                  : (hot ? Style.hoverFillFor(root.foregroundColor, root.accentColor) : "transparent")

                Behavior on color { ColorAnimation { duration: 80 } }

                Row {
                  anchors.fill: parent
                  anchors.leftMargin: Style.spacing.rowPaddingX
                  anchors.rightMargin: Style.spacing.rowPaddingX
                  spacing: Style.spacing.lg

                  Item {
                    id: currentWing
                    width: Style.spacing.xxs
                    height: parent.height
                    visible: parent.parent.isCurrent

                    Rectangle {
                      anchors.verticalCenter: parent.verticalCenter
                      width: parent.width
                      height: Math.max(16, root.rowHeight - Style.spacing.lg)
                      radius: Style.cornerRadius
                      color: root.accentColor
                    }
                  }

                  Text {
                    width: Style.space(40)
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label
                    color: parent.parent.isCurrent ? root.accentColor : root.foregroundColor
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.description
                    color: parent.parent.isCurrent ? root.foregroundColor : root.mutedColor
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    elide: Text.ElideRight
                    width: parent.width - currentWing.width - Style.space(40) - Style.spacing.lg * 2 - (parent.parent.isCurrent ? Style.space(52) : Style.space(16))
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: parent.parent.isCurrent
                    text: "ACTIVE"
                    color: root.accentColor
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }

                MouseArea {
                  id: mouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.selectLayout(modelData.id)
                }
              }
            }
          }

          Text {
            width: parent.width
            text: "Click a layout to switch to it."
            color: root.faintColor
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }
        }

        Column {
          width: parent.width
          spacing: Style.spacing.controlGap
          visible: root.editing

          ListView {
            width: parent.width
            height: root.manageListHeight
            model: root.enabled
            clip: true
            spacing: Style.spacing.xxs

            delegate: Rectangle {
              required property var modelData
              width: parent.width
              height: root.rowHeight
              radius: Style.cornerRadius
              readonly property bool hot: mouse.containsMouse
              color: hot ? Style.hoverFillFor(root.foregroundColor, root.accentColor) : "transparent"

              Behavior on color { ColorAnimation { duration: 80 } }

              Row {
                anchors.fill: parent
                anchors.leftMargin: Style.spacing.rowPaddingX
                anchors.rightMargin: Style.spacing.rowPaddingX
                spacing: Style.spacing.lg

                Text {
                  width: Style.space(40)
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.label
                  color: root.foregroundColor
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.description
                  color: root.mutedColor
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideMiddle
                  width: parent.width - Style.space(40) - Style.spacing.lg * 2 - Style.space(52)
                }

                ToggleSwitch {
                  anchors.verticalCenter: parent.verticalCenter
                  checked: root.hostWidget ? root.hostWidget.enabledIds.indexOf(modelData.id) !== -1 : false
                  interactive: false
                  foreground: root.foregroundColor
                  accent: root.accentColor
                }
              }

              MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleLayout(modelData.id)
              }
            }
          }

          Text {
            width: parent.width
            text: "Toggling off removes the layout. At least one stays active."
            color: root.faintColor
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          PanelSeparator {
            width: parent.width
            foreground: root.foregroundColor
          }

          PanelSectionHeader {
            text: "ADD A LAYOUT"
            foreground: root.foregroundColor
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          }

          TextField {
            width: parent.width
            placeholderText: "Search layouts..."
            foreground: root.foregroundColor
            accent: root.accentColor
            onTextChanged: root.searchText = text
            onAccepted: {
              if (root.filteredCatalog.length > 0)
                root.addLayout(root.filteredCatalog[0].id)
            }
            Keys.onEscapePressed: text = ""
          }

          ListView {
            width: parent.width
            height: root.searchResultsHeight
            model: root.filteredCatalog
            clip: true
            spacing: Style.spacing.xxs
            visible: root.searchText.length > 0

            delegate: Rectangle {
              required property var modelData
              width: parent.width
              height: root.rowHeight
              radius: Style.cornerRadius
              readonly property bool hot: mouse.containsMouse
              color: hot ? Style.hoverFillFor(root.foregroundColor, root.accentColor) : "transparent"

              Behavior on color { ColorAnimation { duration: 80 } }

              Row {
                anchors.fill: parent
                anchors.leftMargin: Style.spacing.rowPaddingX
                anchors.rightMargin: Style.spacing.rowPaddingX
                spacing: Style.spacing.lg

                Text {
                  width: Style.space(40)
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.label
                  color: root.foregroundColor
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.description
                  color: root.mutedColor
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideMiddle
                  width: parent.width - Style.space(40) - Style.spacing.lg * 2 - Style.space(40)
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "+"
                  color: root.accentColor
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
              }

              MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.addLayout(modelData.id)
              }
            }
          }

          Text {
            width: parent.width
            text: root.searchText.length > 0 && root.filteredCatalog.length === 0
              ? "No matching layouts found."
              : root.searchText.length > 0
                ? "Click a layout to add it."
                : "Type to search available layouts."
            color: root.faintColor
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Button {
            width: parent.width
            text: "Done"
            foreground: root.foregroundColor
            accent: root.accentColor
            bordered: true
            onClicked: {
              root.searchText = ""
              root.editing = false
            }
          }
        }
      }
    }
  }
}
