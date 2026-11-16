// Rice Center: one app to see and manage every rice feature (bin/center/main.qml, run by ~/kde-rice/bin/rice-center).
// Native KDE look: Kirigami + KirigamiAddons FormCard, Darkly style (qml-qt6 --apptype widget).
// All work is done by ~/kde-rice/bin/rice-ctl (JSON in/out); this file only shows it.
//   sidebar  → pages; search box filters every feature
//   card     → one feature: switch / choice / settings / actions, "?" shows its how-to from USAGE.md
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard
import org.kde.plasma.plasma5support as P5Support

Kirigami.ApplicationWindow {
    id: app
    title: "Rice Center"
    width: Math.min(980, Screen.desktopAvailableWidth - 40)
    height: Math.min(680, Screen.desktopAvailableHeight - 40)
    minimumWidth: 640
    minimumHeight: 440

    // ------------------------------------------------------------------ data
    readonly property string ctl: '"$HOME/kde-rice/bin/rice-ctl"'
    property var features: []
    property bool loading: true
    property int busy: 0
    property string currentPage: "overview"
    property string search: ""
    readonly property var pages: [
        { id: "overview",    title: "Overview",          icon: "go-home" },
        { id: "everyday",    title: "Everyday",          icon: "preferences-desktop" },
        { id: "look",        title: "Look",              icon: "preferences-desktop-theme-global" },
        { id: "wallpaper",   title: "Wallpaper",         icon: "preferences-desktop-wallpaper" },
        { id: "windows",     title: "Windows & keys",    icon: "preferences-system-windows" },
        { id: "time",        title: "Focus & time",      icon: "chronometer" },
        { id: "power",       title: "Sound & power",     icon: "battery-good" },
        { id: "maintenance", title: "Maintenance",       icon: "tools" },
        { id: "backups",     title: "Looks & backups",   icon: "document-revert" }
    ]

    function shq(t) { return "'" + String(t).replace(/'/g, "'\\''") + "'" }

    // ---- command runner: P5Support executable engine, one callback per request ----
    property var pending: ({})
    property int seq: 0
    P5Support.DataSource {
        id: runner; engine: "executable"; connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            const cb = app.pending[source]
            delete app.pending[source]
            if (cb) cb(String(data.stdout || ""), Number(data["exit code"] || 0), String(data.stderr || ""))
        }
    }
    function run(args, cb) {
        const src = ctl + " " + args + " #" + (++seq)
        pending[src] = cb
        runner.connectSource(src)
    }
    function call(args, label, onDone) {      // change something, then refresh that feature
        busy++
        run(args, (out, rc, err) => {
            busy--
            let r = null
            try { r = JSON.parse(out) } catch (e) {}
            if (!r) { showError((label ? label + ": " : "") + (err || out || "no answer from rice-ctl")); return }
            if (!r.ok) { showError((label ? label + ": " : "") + r.error); refresh(); return }
            if (r.feature) replaceFeature(r.feature)
            if (onDone) onDone(r)
            else if (r.output && r.output.trim().length) showOutput(label || "Done", r.output)
            else showPassiveNotification((label || "Done") + " ✓", "short")
        })
    }
    function refresh() {
        run("list --json", (out) => {
            try { features = JSON.parse(out); loading = false } catch (e) { showError("Could not read the feature list: " + out) }
        })
    }
    function replaceFeature(f) {
        const list = features.slice()
        const i = list.findIndex(x => x.id === f.id)
        if (i >= 0) list[i] = f; else list.push(f)
        features = list
    }
    function inPage(p) {
        if (search.length) {
            const q = search.toLowerCase()
            return features.filter(f => (f.title + " " + f.desc + " " + f.id).toLowerCase().indexOf(q) >= 0)
        }
        return features.filter(f => f.page === p)
    }
    // page model with section headings: [{header: "Sound"}, feature, feature, {header: ...}, ...]
    function pageModel(p) {
        const out = []
        let last = ""
        for (const f of inPage(p)) {
            const sec = search.length ? "" : (f.section || "")
            if (sec && sec !== last) { out.push({ header: sec }); last = sec }
            out.push(f)
        }
        return out
    }
    function showError(t) { errorMsg.text = t; errorMsg.visible = true }
    function showOutput(title, text) { outputDialog.title = title; outputText.text = text; outputDialog.open() }
    function confirm(text, onYes) { confirmDialog.subtitle = text; confirmDialog.onYes = onYes; confirmDialog.open() }
    function showHelp(fid, title) {
        helpDialog.title = title; helpText.text = "…"; helpDialog.open()
        run("help " + fid, (out) => helpText.text = out)
    }

    Component.onCompleted: refresh()

    // test hook (rice-center --shot <file.png> [page]): render the window to a PNG and quit
    readonly property var shotArgs: { const a = Qt.application.arguments, i = a.indexOf("--shot"); return i >= 0 ? a.slice(i + 1) : [] }
    Timer {
        running: app.shotArgs.length > 0 && !app.loading
        interval: 1500
        onTriggered: {
            if (app.shotArgs.length > 1) app.currentPage = app.shotArgs[1]
            Qt.callLater(() => shotDelay.start())
        }
    }
    Timer {
        id: shotDelay; interval: 900
        onTriggered: app.pageStack.grabToImage(r => {
            r.saveToFile(app.shotArgs[0])
            drawer.contentItem.grabToImage(r2 => { r2.saveToFile(app.shotArgs[0].replace(/\.png$/, "-side.png")); Qt.quit() })
        })
    }
    onActiveChanged: if (active && !loading && busy === 0) refresh()      // pick up changes made elsewhere

    // ------------------------------------------------------------------ sidebar
    globalDrawer: Kirigami.GlobalDrawer {
        id: drawer
        isMenu: false
        modal: false
        collapsible: false
        width: Kirigami.Units.gridUnit * 13
        header: Kirigami.AbstractApplicationHeader {
            contentItem: Kirigami.SearchField {
                id: searchField
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                placeholderText: "Search features…"
                onTextChanged: app.search = text
            }
        }
        actions: app.pages.map(p => pageAction.createObject(drawer, { pid: p.id, text: p.title, iconName: p.icon }))
    }
    Component {
        id: pageAction
        Kirigami.Action {
            property string pid
            property string iconName
            icon.name: iconName
            checkable: true
            checked: app.currentPage === pid && !app.search.length
            onTriggered: { searchField.text = ""; app.currentPage = pid }
        }
    }

    pageStack.initialPage: mainPage
    pageStack.globalToolBar.style: Kirigami.ApplicationHeaderStyle.None

    FormCard.FormCardPage {
        id: mainPage
        title: app.search.length ? "Search" : (app.pages.find(p => p.id === app.currentPage) || {}).title || ""

        header: ColumnLayout {
            spacing: 0
            Kirigami.InlineMessage {
                id: errorMsg
                Layout.fillWidth: true
                type: Kirigami.MessageType.Error
                showCloseButton: true
                visible: false
                position: Kirigami.InlineMessage.Position.Header
            }
            QQC2.ProgressBar {
                Layout.fillWidth: true
                indeterminate: true
                visible: app.busy > 0 || app.loading
                Layout.preferredHeight: visible ? implicitHeight : 0
            }
        }

        FormCard.FormHeader {
            title: app.search.length ? ("Results for “" + app.search + "”") : mainPage.title
        }
        FormCard.FormSectionText {
            visible: app.currentPage === "overview" && !app.search.length && app.features.length > 0
            text: {
                const t = app.features.filter(f => f.on === true || f.on === false)
                return t.filter(f => f.on).length + " of " + t.length + " features on · rice-ctl list shows the same in a terminal"
            }
        }
        Repeater {
            model: app.pageModel(app.currentPage)
            delegate: Loader {
                required property var modelData
                Layout.fillWidth: true
                sourceComponent: modelData.header ? sectionHeader : featureCard
                Component { id: featureCard; FeatureCard { f: modelData } }
                Component { id: sectionHeader; FormCard.FormHeader { title: modelData.header } }
            }
        }
        FormCard.FormSectionText {
            visible: app.search.length && app.inPage("").length === 0
            text: "Nothing matches."
        }
        Item { implicitHeight: Kirigami.Units.gridUnit }
    }

    // ------------------------------------------------------------------ one feature
    component FeatureCard: ColumnLayout {
        id: card
        property var f
        Layout.fillWidth: true
        spacing: 0

        FormCard.FormCard {
            Layout.topMargin: Kirigami.Units.largeSpacing
            // --- main row ---
            FormCard.FormSwitchDelegate {
                visible: card.f.kind === "toggle"
                text: card.f.title
                description: card.f.desc + (card.f.detail ? "\n" + card.f.detail : "")
                checked: card.f.on === true
                enabled: app.busy === 0
                onToggled: {
                    const want = checked
                    checked = Qt.binding(() => card.f.on === true)
                    app.call((want ? "on " : "off ") + card.f.id + card.optArgs(), card.f.title + (want ? " on" : " off"))
                }
                trailing: HelpButton { fid: card.f.id; ftitle: card.f.title; visible: !!card.f.help }
            }
            FormCard.FormComboBoxDelegate {
                visible: card.f.kind === "choice"
                text: card.f.title
                description: card.f.desc + (card.f.detail ? "\n" + card.f.detail : "")
                model: (card.f.options || []).map(o => ({ value: o[0], text: o[1] }))
                textRole: "text"
                valueRole: "value"
                displayMode: FormCard.FormComboBoxDelegate.ComboBox
                currentIndex: (card.f.options || []).findIndex(o => o[0] === card.f.value)
                enabled: app.busy === 0
                onActivated: {
                    const v = (card.f.options || [])[currentIndex][0]
                    currentIndex = Qt.binding(() => (card.f.options || []).findIndex(o => o[0] === card.f.value))
                    if (v === card.f.value) return
                    const go = () => app.call("set " + card.f.id + " " + app.shq(v) + card.optArgs(), card.f.title)
                    if (card.f.confirm) app.confirm(card.f.confirm, go); else go()
                }
            }
            FormCard.FormTextDelegate {
                visible: card.f.kind === "report" || card.f.kind === "actions" || card.f.kind === "list"
                text: card.f.title
                description: [card.f.desc, card.f.value, card.f.detail].filter(x => x && String(x).length).join("\n")
                trailing: HelpButton { fid: card.f.id; ftitle: card.f.title; visible: !!card.f.help }
            }

            // --- settings ---
            Repeater {
                model: card.f.settings || []
                delegate: Loader {
                    required property var modelData
                    Layout.fillWidth: true
                    sourceComponent: modelData.type === "int" ? intSetting : modelData.type === "bool" ? boolSetting : choiceSetting
                    property var s: modelData
                }
            }
            Component {
                id: intSetting
                FormCard.FormSpinBoxDelegate {
                    id: spin
                    readonly property var s: parent.s
                    readonly property int current: card.localOpts[s.key] !== undefined ? card.localOpts[s.key] : s.value
                    label: s.label
                    from: s.min; to: s.max
                    value: current
                    enabled: app.busy === 0
                    // no "modified" signal here: save 0.6 s after the last change that isn't just the current value
                    onValueChanged: if (value !== current) settle.restart()
                    Timer { id: settle; interval: 600; onTriggered: if (spin.value !== spin.current) card.setOpt(spin.s.key, spin.value) }
                }
            }
            Component {
                id: boolSetting
                FormCard.FormCheckDelegate {
                    text: parent.s.label
                    checked: card.localOpts[parent.s.key] !== undefined ? card.localOpts[parent.s.key] : parent.s.value
                    enabled: app.busy === 0
                    onToggled: card.setOpt(parent.s.key, checked)
                }
            }
            Component {
                id: choiceSetting
                FormCard.FormComboBoxDelegate {
                    text: parent.s.label
                    model: parent.s.options.map(o => ({ value: o[0], text: o[1] }))
                    textRole: "text"; valueRole: "value"
                    displayMode: FormCard.FormComboBoxDelegate.ComboBox
                    currentIndex: parent.s.options.findIndex(o => String(o[0]) === String(card.localOpts[parent.s.key] !== undefined ? card.localOpts[parent.s.key] : parent.s.value))
                    enabled: app.busy === 0
                    onActivated: card.setOpt(parent.s.key, parent.s.options[currentIndex][0])
                }
            }

            // --- snapshot list ---
            // plain TextField: FormTextFieldDelegate needs KDE's i18n context, which qml-qt6 doesn't provide
            FormCard.AbstractFormDelegate {
                visible: card.f.kind === "list"
                Layout.fillWidth: true
                background: null
                contentItem: RowLayout {
                    QQC2.Label { text: "New snapshot name" }
                    QQC2.TextField {
                        id: snapName
                        Layout.fillWidth: true
                        placeholderText: "e.g. before-experiment"
                        maximumLength: 40
                    }
                }
            }
            FormCard.FormButtonDelegate {
                visible: card.f.kind === "list"
                text: "Snapshot now"
                icon.name: "document-save"
                enabled: app.busy === 0
                onClicked: app.call("action snapshots create " + app.shq(snapName.text || "manual"), "Snapshot")
            }
            Repeater {
                model: card.f.kind === "list" ? (card.f.items || []) : []
                delegate: FormCard.FormButtonDelegate {
                    required property var modelData
                    text: modelData.name.replace(/^\d+-pre-/, "")
                    description: "#" + modelData.name.split("-")[0] + " · " + modelData.date
                    icon.name: "document-revert"
                    enabled: app.busy === 0
                    onClicked: app.confirm("Restore “" + modelData.name + "”? " +
                                           (card.f.actions.find(a => a.id === "restore") || {}).confirm,
                                           () => app.call("action snapshots restore " + app.shq(modelData.name), "Restore"))
                }
            }

            // --- actions ---
            Repeater {
                model: (card.f.actions || []).filter(a => !a.per_item && !(card.f.kind === "list" && a.id === "create"))
                delegate: FormCard.FormButtonDelegate {
                    required property var modelData
                    text: modelData.label
                    icon.name: modelData.danger ? "edit-delete" : modelData.output ? "document-preview" : "media-playback-start"
                    enabled: app.busy === 0
                    onClicked: {
                        const go = () => app.call("action " + card.f.id + " " + modelData.id + card.optArgs(), modelData.label)
                        if (modelData.confirm) app.confirm(modelData.confirm, go); else go()
                    }
                }
            }
        }

        // settings that only matter when switching on (focus minutes, awake hours) stay in the app until used
        property var localOpts: ({})
        function setOpt(key, value) {
            const o = Object.assign({}, localOpts); o[key] = value; localOpts = o
            if (!card.f.local_settings && card.f.id !== "look")
                app.call("set " + card.f.id + " " + key + " " + app.shq(value === true ? "1" : value === false ? "0" : value), card.f.title)
        }
        function optArgs() {
            let s = ""
            const src = Object.assign({}, ...(card.f.settings || []).map(x => ({ [x.key]: x.value })), localOpts)
            if (card.f.local_settings || card.f.id === "look")
                for (const k in src) s += " --opt " + app.shq(k + "=" + (src[k] === true ? "1" : src[k] === false ? "0" : src[k]))
            return s
        }
    }

    component HelpButton: QQC2.ToolButton {
        property string fid
        property string ftitle
        icon.name: "help-contextual"
        display: QQC2.AbstractButton.IconOnly
        text: "How to use"
        QQC2.ToolTip.text: text
        QQC2.ToolTip.visible: hovered
        onClicked: app.showHelp(fid, ftitle)
    }

    // ------------------------------------------------------------------ dialogs
    Kirigami.PromptDialog {
        id: confirmDialog
        property var onYes: null
        title: "Are you sure?"
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: if (onYes) onYes()
    }
    Kirigami.Dialog {
        id: outputDialog
        preferredWidth: Math.min(app.width - Kirigami.Units.gridUnit * 4, Kirigami.Units.gridUnit * 40)
        preferredHeight: Math.min(app.height - Kirigami.Units.gridUnit * 4, Kirigami.Units.gridUnit * 30)
        standardButtons: Kirigami.Dialog.Close
        QQC2.ScrollView {
            QQC2.TextArea {
                id: outputText
                readOnly: true
                wrapMode: TextEdit.Wrap
                font.family: "JetBrainsMono Nerd Font"
                textFormat: TextEdit.PlainText
                background: null
            }
        }
    }
    Kirigami.Dialog {
        id: helpDialog
        preferredWidth: Math.min(app.width - Kirigami.Units.gridUnit * 4, Kirigami.Units.gridUnit * 40)
        preferredHeight: Math.min(app.height - Kirigami.Units.gridUnit * 4, Kirigami.Units.gridUnit * 32)
        standardButtons: Kirigami.Dialog.Close
        QQC2.ScrollView {
            QQC2.TextArea {
                id: helpText
                readOnly: true
                wrapMode: TextEdit.Wrap
                textFormat: TextEdit.MarkdownText
                background: null
            }
        }
    }
}
