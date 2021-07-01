import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtQuick.Controls.Material 2.2
import QtGraphicalEffects 1.0

Flickable {

    id: settingsPanel
    objectName: 'yubiKeyWebAuthnView'
    contentWidth: app.width
    contentHeight: expandedHeight
    StackView.onActivating: {
        yubiKey.refreshCurrentDevice()
        if (uvBlocked) {
            navigator.confirmInput({
                "pinMode": true,
                "manageMode": false,
                "heading": "Unlock YubiKey",
                "text1": "Too many fingerprint scanning attempts have been used, PIN is required to unlock YubiKey.",
                "acceptedCb": function(resp) {
                    yubiKey.refreshCurrentDevice()
                }
            })
        }
    }

    property bool isBusy

    property var expandedHeight: content.implicitHeight + dynamicMargin
    property bool hasPin: !!yubiKey.currentDevice && yubiKey.currentDevice.fidoHasPin
    property int pinRetries: !!yubiKey.currentDevice && yubiKey.currentDevice.fidoPinRetries
    property bool pinIsBlocked: !!yubiKey.currentDevice && yubiKey.pinIsBlocked
    property bool uvBlocked: !!yubiKey.currentDevice && yubiKey.currentDevice.uvBlocked

    onUvBlockedChanged: {
        if (uvBlocked) {
            navigator.confirmInput({
                "pinMode": true,
                "manageMode": false,
                "heading": "Unlock YubiKey",
                "text1": "Too many fingerprint scanning attempts have been used, PIN is required to unlock YubiKey.",
                "acceptedCb": function(resp) {
                    yubiKey.refreshCurrentDevice()
                }
            })
        }
    }

    onExpandedHeightChanged: {
        if (expandedHeight > app.height - toolBar.height) {
             scrollBar.active = true
         }
    }

    ScrollBar.vertical: ScrollBar {
        id: scrollBar
        width: 8
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        hoverEnabled: true
        z: 2
    }
    boundsBehavior: Flickable.StopAtBounds

    property string searchFieldPlaceholder: ""

    Pane {
        visible: !yubiKey.currentDevice
        height: app.height
        width: app.width
        NoYubiKeySection {
            id: noYubiKeySection
            enabled: visible
            Accessible.ignored: true
        }
    }

    ColumnLayout {
        width: settingsPanel.contentWidth
        id: content
        spacing: 0
        visible: !!yubiKey.currentDevice

        ColumnLayout {
            width: settingsPanel.contentWidth - 32
            Layout.leftMargin: 16
            Layout.rightMargin: 16

            Label {
                text: "WebAuthn (FIDO2/U2F)"
                font.pixelSize: 16
                font.weight: Font.Normal
                color: yubicoGreen
                opacity: fullEmphasis
                Layout.topMargin: 24
                Layout.bottomMargin: 24
            }

            Label {
                text: qsTr("WebAuthn is a credential management API that lets web applications authenticate users without storing their passwords on servers.")
                color: primaryColor
                opacity: lowEmphasis
                font.pixelSize: 13
                lineHeight: 1.2
                textFormat: TextEdit.PlainText
                wrapMode: Text.WordWrap
                Layout.maximumWidth: parent.width
                Layout.bottomMargin: 16
            }
        }

        StyledExpansionContainer {
            StyledExpansionPanel {
                label: qsTr("PIN protection")
                enabled: !pinIsBlocked
                isEnabled: false
                actionButton.text: hasPin ? qsTr("Change PIN") : qsTr("Create a PIN")
                actionButton.onClicked: navigator.confirmInput({
                    "pinMode": true,
                    "manageMode": true,
                    "heading": actionButton.text,
                    "acceptedCb": function(resp) {
                        yubiKey.refreshCurrentDevice()
                    }
                })
            }

            StyledExpansionPanel {
                label: qsTr("Sign-in data")
                visible: !!yubiKey.currentDevice && yubiKey.currentDeviceEnabled("FIDO2")
                enabled: pinRetries > 0 && hasPin
                description: qsTr("View and delete sign-in data stored on your security key")
                isFlickable: true
                expandButton.onClicked: {
                    if (!!yubiKey.currentDevice && yubiKey.currentDevice.fidoPinCache && yubiKey.currentDevice.fidoPinCache !== "") {
                        navigator.goToFidoCredentialsView()
                    } else {
                        navigator.confirmInput({
                            "pinMode": true,
                            "heading": label,
                            "acceptedCb": function() {
                                navigator.goToFidoCredentialsView()
                            }
                        })
                    }
                } 
            }

            StyledExpansionPanel {
                label: qsTr("Fingerprints")
                visible: !!yubiKey.currentDevice && yubiKey.currentDeviceEnabled("FIDO2") && (yubiKey.currentDevice.formFactor === 6 || yubiKey.currentDevice.formFactor === 7)
                enabled: pinRetries > 0 && hasPin
                description: qsTr("Add and delete fingerprints")
                isFlickable: true
                expandButton.onClicked: {
                    if (!!yubiKey.currentDevice && yubiKey.currentDevice.fidoPinCache && yubiKey.currentDevice.fidoPinCache !== "") {
                            navigator.goToFingerPrintsView()
                    } else {
                        navigator.confirmInput({
                            "pinMode": true,
                            "heading": label,
                            "acceptedCb": function(resp) {
                                navigator.goToFingerPrintsView()
                            }
                        })
                    }
                }
            }
            StyledExpansionPanel {
                label: qsTr("Factory defaults")
                isEnabled: false
                actionButton.text: "Reset"
                actionButton.onClicked: navigator.confirmFidoReset({
                    "acceptedCb": function(resp) {
                        yubiKey.refreshCurrentDevice()
                    }
                })
            }
        }
    }
}
