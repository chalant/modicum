import tkinter as tk

import threading

from gscrap.tools import window_selection

window = tk.Tk()

window.title("Window Selector")

window.geometry("200x200")

selector = window_selection.WindowSelector(window)
selected = threading.Event()

tk.Button(window, text="Select Window", command=start_selection)

class EventHandler(object):
    def __init__(self):
        self._selected = threading.Event()

        self._window = None

    def on_selected(self, event):
        self._selected.set()

    def on_abort(self, event):
        pass

    def on_error(self, event):
        pass

    def get_window(self):
        self._selected.wait()
        self._selected.clear()

        return self._window


eh = EventHandler()

def start():
    selector.start_selection(eh.on_selected, eh.on_abort, eh.on_error)

    #blocks until a window is returned or we exit application.
    return eh.get_window()