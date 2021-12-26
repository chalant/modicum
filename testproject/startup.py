from concurrent import futures

import tkinter as tk

import grpc

from glog import poker_server_pb2_grpc, table_server

from gscrap.data.filters import filter_pipelines
from gscrap.projects import projects

from gscrap.tools import window_selection

root = tk.Tk()

root.title("PokerTH")
root.geometry("200x200")

class Application(object):
    def __init__(
            self,
            container,
            table_server,
            game_client,
            game_settings):
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

        self._game_client = game_client
        self._game_settings = game_settings

    def _start_selection(self):
        self._window_selector.start_selection(
            self._on_window_selected,
            self._on_abort,
            self._on_error
        )

    def _on_window_selected(self, window_event):
        self._pkr_table.set_window(window_event)

        #TODO: wait for table scene

        print("Starting game client...")

        self._game_client.start(self._game_settings)

        self._pkr_table.set_to_ready()

    def _on_error(self):
        pass

    def _on_abort(self):
        pass

def start(workspace, game_settings, game_client, server_url='localhost:50051'):

    project = projects.Project(workspace)

    fp = filter_pipelines.FilterPipelines()

    tb = table_server.PokerTableServer(
        project.load_scene("table"),
        game_settings,
        fp)

    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))

    poker_server_pb2_grpc.add_PokerServiceServicer_to_server(tb, server)

    server.add_insecure_port(server_url)

    # todo: start game solver in a different thread subprocess passing in the server address
    # the solver will call the IsReady function of the server and will block.

    server.start()

    #todo: make a game client object that encapsulates a process and pass it as argument

    Application(
        root,
        tb,
        game_client,
        game_settings
    )

    root.mainloop()
