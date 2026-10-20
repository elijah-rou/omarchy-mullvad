import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// The VPN shield glyph Omarchy's Tailscale panel already uses for Mullvad
// regions, with a strike-through while off and a badge for states that need
// attention (logged out, blocked, tunnel error).
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Commons.Color.foreground
  property color badgeColor: Commons.Color.urgent
  property string fontFamily: Style.font.family
  property bool crossed: false
  property bool warning: false
  property bool pulsing: false

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  Text {
    id: glyph
    anchors.centerIn: parent
    text: "󰖂"
    color: root.color
    font.family: root.fontFamily
    font.pixelSize: root.iconSize

    SequentialAnimation on opacity {
      running: root.pulsing
      loops: Animation.Infinite
      NumberAnimation { to: 0.35; duration: 520; easing.type: Easing.InOutQuad }
      NumberAnimation { to: 1.0; duration: 520; easing.type: Easing.InOutQuad }
      onRunningChanged: if (!running) glyph.opacity = 1.0
    }
  }

  Rectangle {
    visible: root.crossed
    anchors.centerIn: parent
    width: parent.width * 1.18
    height: Math.max(2, parent.height * 0.12)
    radius: height / 2
    color: root.color
    rotation: -45
  }

  BorderSurface {
    visible: root.warning
    width: Math.max(7, parent.width * 0.42)
    height: width
    radius: width / 2
    color: root.badgeColor
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    borderSpec: Border.flat(Commons.Color.popups.background, 1)

    Text {
      anchors.centerIn: parent
      text: "!"
      color: Commons.Color.background
      font.family: Style.font.family
      font.pixelSize: Math.max(6, parent.height * 0.72)
      font.bold: true
    }
  }
}
