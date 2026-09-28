"""Conservative sizing: retain the original layout, fit controls and screen."""
from PyQt6.QtCore import QObject, QEvent, QTimer, QSize
from PyQt6.QtWidgets import QWidget, QPushButton, QComboBox, QLineEdit, QScrollArea, QFrame, QLayout
from PyQt6 import sip


class OriginalLayoutFit(QObject):
    def __init__(self, window, body, outer):
        super().__init__(window)
        self.window, self.body, self.outer = window, body, outer
        self.pending = False
        self.viewport = None
        self.handle = None
        window.installEventFilter(self)

    def eventFilter(self, watched, event):
        if event.type() in (QEvent.Type.Show,QEvent.Type.FontChange,QEvent.Type.ApplicationFontChange):
            self.schedule()
        return False

    def schedule(self):
        if not self.pending:
            self.pending=True
            QTimer.singleShot(0,self.fit)

    def fit(self):
        self.pending=False
        w=self.window
        if sip.isdeleted(w):
            return
        # Only enlarge fixed text controls when the font actually needs it.
        for control in self.body.findChildren(QWidget):
            if not isinstance(control,(QPushButton,QComboBox,QLineEdit)):
                continue
            if isinstance(control,QPushButton) and not control.text():
                continue
            if control.objectName() in {'tabAddButton','tabHoverClose','editorIconButton'}:
                continue
            hint=control.sizeHint()
            if control.minimumHeight()==control.maximumHeight() and 18<=control.height()<=70:
                control.setFixedHeight(max(control.height(),hint.height()))
            if control.minimumWidth()==control.maximumWidth():
                control.setFixedWidth(max(control.width(),hint.width()))
        self.body.layout().activate()
        if not w.isWindow() or w.screen() is None:
            return
        handle=w.windowHandle()
        if handle is not None and handle is not self.handle:
            self.handle=handle
            handle.screenChanged.connect(lambda _screen:self.schedule())
        area=w.screen().availableGeometry().adjusted(12,12,-12,-12)
        required=self.body.minimumSizeHint()
        needed_width=max(w.minimumWidth(),required.width())
        needed_height=max(w.minimumHeight(),required.height()+39)
        # Existing list scroll areas have their own content minimums.
        for scroll in self.body.findChildren(QScrollArea):
            content=scroll.widget()
            if content is not None:
                needed_width=max(needed_width,content.minimumSizeHint().width()+max(0,w.width()-scroll.viewport().width()))
        constrained=needed_width>area.width() or needed_height>area.height()
        if constrained and self.viewport is None:
            self.outer.removeWidget(self.body)
            self.viewport=QScrollArea()
            self.viewport.setFrameShape(QFrame.Shape.NoFrame)
            self.viewport.setWidgetResizable(True)
            self.viewport.setWidget(self.body)
            self.outer.addWidget(self.viewport,1)
            self.outer.setSizeConstraint(QLayout.SizeConstraint.SetNoConstraint)
            w._blur_body=self.viewport
        elif not constrained and self.viewport is not None:
            self.viewport.takeWidget()
            self.outer.removeWidget(self.viewport)
            self.viewport.deleteLater()
            self.viewport=None
            self.outer.addWidget(self.body,1)
            self.body.show()
            self.outer.setSizeConstraint(QLayout.SizeConstraint.SetDefaultConstraint)
            w._blur_body=self.body
        w.setMinimumSize(min(needed_width,area.width()),min(needed_height,area.height()))
        w.resize(min(max(w.width(),needed_width),area.width()),min(max(w.height(),needed_height),area.height()))
        w.move(max(area.left(),min(w.x(),area.right()-w.width()+1)),max(area.top(),min(w.y(),area.bottom()-w.height()+1)))
