"""Shared desktop transitions and optional single-window navigation."""
from PyQt6.QtCore import QObject, QEvent, QEventLoop, QTimer, QPropertyAnimation, QEasingCurve, Qt, QSize
from PyQt6.QtWidgets import QGraphicsOpacityEffect, QStackedWidget, QPushButton
from PyQt6 import sip


def fade_in_card(card, scroll=None):
    effect = QGraphicsOpacityEffect(card)
    card.setGraphicsEffect(effect)
    effect.setOpacity(0.0)
    animation = QPropertyAnimation(effect, b'opacity', card)
    animation.setDuration(750)
    animation.setStartValue(0.0)
    animation.setEndValue(1.0)
    animation.setEasingCurve(QEasingCurve.Type.InOutQuad)
    card._install_fade = animation
    def reveal():
        if sip.isdeleted(card):
            return
        if scroll is not None and not sip.isdeleted(scroll):
            scroll.ensureWidgetVisible(card, 0, 24)
        animation.start()
    QTimer.singleShot(0, reveal)


class WindowRouter(QObject):
    """Embed modeless feature dialogs; keep modal confirmations as dialogs."""
    def __init__(self, owner, icon):
        super().__init__(owner)
        self.owner = owner
        self.icon = icon
        self.stack = None
        self.pages = []
        self.records = {}
        self.changing = False

    def single(self):
        return self.owner.settings.value('application/window_mode', 'multiple') == 'single'

    def register(self, window):
        if window is self.owner or window in self.records:
            return
        record = {'show': window.show, 'parent': window.parentWidget(), 'flags': window.windowFlags(),
                  'minimum': window.minimumSize(), 'maximum': window.maximumSize(), 'size': window.size()}
        self.records[window] = record
        def show():
            if self.single() and not window.isModal():
                self.open(window)
            else:
                record['show']()
        window.show = show
        if hasattr(window, 'exec'):
            native_exec = window.exec
            def execute():
                if not self.single():
                    return native_exec()
                loop = QEventLoop(window)
                window.finished.connect(loop.quit)
                self.open(window)
                try:
                    loop.exec()
                    return window.result()
                finally:
                    window.finished.disconnect(loop.quit)
                    loop.deleteLater()
                    self.remove_page(window)
            window.exec = execute
        window.installEventFilter(self)
        window.destroyed.connect(lambda _=None, w=window: self.forget(w))

    def open(self, window):
        if self.stack is None:
            self.stack = QStackedWidget(self.owner)
            self.home = self.owner.takeCentralWidget()
            self.stack.addWidget(self.home)
            self.owner.setCentralWidget(self.stack)
        self.changing = True
        try:
            record = self.records[window]
            if self.stack.indexOf(window) < 0:
                record.update(minimum=window.minimumSize(), maximum=window.maximumSize(), size=window.size())
                window.hide()
                window.setParent(self.stack, Qt.WindowType.Widget)
                window.clearMask()
                window.setMinimumSize(0, 0)
                window.setMaximumSize(16777215, 16777215)
                self.stack.addWidget(window)
                bar = getattr(window, '_blur_title_bar', None)
                if bar is not None:
                    back = QPushButton()
                    back.setToolTip('Back')
                    back.setFixedSize(30, 28)
                    back.setIcon(self.icon('back'))
                    back.setIconSize(QSize(17, 17))
                    back.clicked.connect(lambda: self.back(window))
                    bar.layout().insertWidget(0, back)
                    record['back'] = back
                    bar._topmost_timer.stop()
                    bar.pin_button.hide()
                    bar.min_button.hide()
            if window in self.pages:
                self.pages.remove(window)
            self.pages.append(window)
            self.stack.setCurrentWidget(window)
            self.records[window]['show']()
        finally:
            self.changing = False

    def back(self, window):
        # close() runs the builder's unsaved-change guard and can be cancelled.
        if window.close():
            self.remove_page(window)

    def forget(self, window):
        self.records.pop(window, None)
        self.remove_page(window)

    def remove_page(self, window):
        if window in self.pages:
            self.pages.remove(window)
        self.pages = [page for page in self.pages if not sip.isdeleted(page)]
        if self.stack is not None and not sip.isdeleted(self.stack):
            target = self.pages[-1] if self.pages else self.home
            if not sip.isdeleted(target):
                self.stack.setCurrentWidget(target)

    def eventFilter(self, watched, event):
        if event.type() == QEvent.Type.Hide and not self.changing and self.pages and watched is self.pages[-1]:
            QTimer.singleShot(0, lambda w=watched: self.remove_page(w) if not sip.isdeleted(w) and not w.isVisible() else None)
        return False

    def apply_mode(self):
        if self.single():
            visible = [w for w in self.records if not sip.isdeleted(w) and w.isVisible() and not w.isModal()]
            for w in visible:
                self.open(w)
            return
        self.changing = True
        try:
            active = self.pages[-1] if self.pages else None
            self.pages.clear()
            if self.stack is not None:
                self.stack.setCurrentWidget(self.home)
                for window, record in list(self.records.items()):
                    if sip.isdeleted(window) or self.stack.indexOf(window) < 0:
                        continue
                    self.stack.removeWidget(window)
                    window.setParent(record['parent'], record['flags'])
                    window.setMinimumSize(record['minimum'])
                    window.setMaximumSize(record['maximum'])
                    window.resize(record['size'])
                    if record.get('back'):
                        record.pop('back').deleteLater()
                    bar = getattr(window, '_blur_title_bar', None)
                    if bar:
                        bar.pin_button.show()
                        bar.min_button.show()
                    if window is active:
                        record['show']()
        finally:
            self.changing = False
