import os

import json

import subprocess

import click

from gscrap.projects import projects
from gscrap.projects import workspace

class GameClient(object):
    def __init__(self, server_url, script_path):
        self._process = None
        self._server_url = server_url
        self._script_path = script_path

    def start(self, game_settings):
        self._process = subprocess.Popen([
            'julia',
            self._script_path,
            '--chips', game_settings['chips'],
            '--small_blind', game_settings['small_blind'],
            '--big_blind', game_settings['big_blind'],
            '-tpt', game_settings['time_per_turn'],
            '--server_url', self._server_url])

    def stop(self):
        if self._process:
            self._process.terminate()

@click.group()
def main():
    pass

@main.command()
@click.argument('name')
def create(project_name):
    pass

@main.command()
@click.argument('project_name')
def start(project_name):
    cwd = os.getcwd()

    server_url = 'localhost::50051'

    wks = workspace.WorkSpace(cwd, project_name)

    startup_file_path = os.path.join(wks.project_dir, "startup.py")

    namespace = {}

    with open(startup_file_path, 'r') as f:
        code = compile(f.read(), startup_file_path, 'exec')
        exec(code, namespace)

    with open(os.path.join(wks.project_dir, "settings.json")) as f:
        settings = json.load(f)

    num_players = settings["num_players"]

    if num_players == 2:
        game_client = GameClient(
            server_url,
            os.path.join(cwd, 'headsup.jl'))

    elif num_players > 2:
        raise ValueError("{} Player mode not supported".join(num_players))

    namespace.get('start')(
        wks,
        settings,
        game_client,
        server_url,
    )

    #todo: handle terminating game client from here!

    # we have an initial scene (we can start from an arbitrary scene, preferably a confirmation scene),

    # and a last scene (the last scene prompts us to launch a new game or to quit)
    # the first scene and last scene are controlled by the code logic (ex:
    # the logger controls when the game starts and when to quit.
    # note: we need to wait for an opponent sometimes... we an opponent is found, a message
    # appears, we could also detect when a player is seated or not...

    # todo: 1) prompt user to select game window
    #         1.1) should specify additional data manually (num_players?)
    #         1.2) should launch a detection loop to detect the first scene.
    #              once the first scene has been detected, the logger is ready to start.
    #      2) launch game solver process with known initial data (game type, chips etc.) as argument
    #             the solver will make a request to the server and will block until it receives
    #             the initial data (use threading.Event())

    # could pass in "known" data like number of players, chips and blind amounts (which are the initial game settings)

    # note: this script has a specific "game" and game options as target
    #       like number of players etc. Waits for a particular scene to be
    #       detected. For now, we assume the user selects the expected window
    #       once the window is selected, we prompt to user to confirm start.
    #       once the user confirms, we can start the initial detection loop, to detect the first
    #       scene.

    # we should streamline this process in the future to make it less error prone and more consistent
    # maybe launch a process that handles this and returns a window_id?

    # we could load game settings from a file.

    # 1) create table server and start listening to a local port
    # 2) start game process with server address, num_players etc. as arguments


    # 1) wait for user to select window.
    # 2) once the window is selected, load "first scene" data and loop to detect first scene
    #    in the window.
    # 3) once the first scene is detected, prompt the user to confirm if he wants to play
    # 4) if the user selected  yes, call the "is_ready" method of the table server. This will unblock the server subprocess.

    #todo: need to load settings associated with the project
    # for now we will pass settings in the cli num_players, sb and bb

if __name__ == '__main__':
    main()