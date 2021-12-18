from os import path

import json

from concurrent import futures

import tkinter as tk

import grpc

from glog import poker_server_pb2_grpc, table_server
from glog import poker_messages_pb2 as msg

from gscrap.data.filters import filter_pipelines
from gscrap.projects import projects

from gscrap.tools import window_selection

root = tk.Tk()

root.title("PokerTH")
root.geometry("200x200")

class Application(object):
    def __init__(self, container, table_server):
        """

        Parameters
        ----------
        container
        table_server: glog.table_server.PokerTableServer
        """
        self._select_window = sw = tk.Button(
            container,
            text="Select Window",
            command=self._start_selection)

        sw.pack()

        self._window_selector = window_selection.WindowSelector(container)

        self._pkr_table = table_server

    def _start_selection(self):
        self._window_selector.start_selection(
            self._on_window_selected,
            self._on_abort,
            self._on_error
        )

    def _on_window_selected(self, window_event):
        self._pkr_table.set_window(window_event)
        self._pkr_table.set_to_ready()

    def _on_error(self):
        pass

    def _on_abort(self):
        pass

def start(workspace):
    project = projects.Project(workspace)

    fp = filter_pipelines.FilterPipelines()

    with open(path.join(workspace.project_dir, "settings.json")) as f:
        settings = json.load(f)

    tb = table_server.PokerTableServer(
        project.load_scene("table"),
        settings,
        fp)

    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))

    poker_server_pb2_grpc.add_PokerServiceServicer_to_server(tb, server)

    server.add_insecure_port('localhost:50051')

    # todo: start game solver in a different thread subprocess passing in the server address
    # the solver will call the IsReady function of the server and will block.

    server.start()

    Application(root, tb)

    root.mainloop()
