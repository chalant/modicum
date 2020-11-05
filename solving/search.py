import play
import nodes


class Node(object):
    def __init__(self, node):
        self.children = {}


def select_node(nodes):
    return

def select_action(actions):
    return

def search(game, state, action_sampler, iterations):
    #todo: pass a subtree to the search function => the search doesn't expand the tree,
    # it stops when it reaches a "leaf" node, so we pass-in an already built subgame tree
    # the subgame tree start at some root node and ends at some round (ex: flop, turn, river)
    # at the river we solve to the end of the game.
    # upon reaching a leaf node, there is an additional turn for the opponent(s) in which he chooses
    # a strategy that will be played during the roll out

    # iterations (1600 in alpha-go)
    # the state is the representation of the current game state (deck, private cards etc.)
    #we need to check if a node has been explored
    # if a node has been explored, expand (add its child nodes to the tree),
    # if a node has node been explored, simulate and update its value
    # simulate: from root, play the remaining hand => sample

    # note: search just updates the strategy. It doesn't "expand" the base tree.
    stack = []

    root = state.root
    # todo: for each "info-set" we keep track of the number of explorations
    # todo: does the search expand the "base" tree?
    #select an action of this node
    #todo: check if the node is terminal if it is, compute the utility and pass the value
    # to the previous node in the stack

    # explore all actions from the root node, then from the resulting simulations,
    # select a node to explore (we select the node with the highest value)
    children = root.children
    # expand the tree by selecting and playing an action selected randomly
    # from a set of actions

    #todo: all the children of the tree are discarded except for the chosen action at
    # the end.

    #todo: depth-limit would mean that we don't do search until terminal node
    # but instead do it until the end of a round

    for i in range(iterations):
        #starting from the root, select an perform an action
        node = game.play(
            state.community_cards,
            state.private_cards,
            state.players,
            root,
            children,
            [select_action(root.actions)])[0]

        stack.append(node) #root node

        # todo: include depth limit
        while True:
            n = stack[-1]
            # simulate a game
            visits = n.visits
            #first visit => leaf node => simulate rest of the game.
            # todo: the opponent can choose between k strategies to play for the
            #  simulation
            if visits == 0:
                #leaf node (unvisited)
                #todo: back-propagate the result to the parent node
                # and break loop
                # todo: update rewards

                #note: in simulations, players choose actions based on strategy (policy)
                result = play.simulate(
                    game,
                    n,
                    state,)
                visits += 1
                n.explorations = visits
                while stack:
                    #todo: update values of the previous nodes
                    r = stack.pop()
                    r.visits += 1
                #break the loop
                break
            else:
                #expand tree
                j = game.play(
                    state.community_cards,
                    state.private_cards,
                    state.players,
                    n,
                    n.children,
                    [select_action(n.actions)]
                )[0]


                if j.type == nodes.TERMINAL:
                    #todo: compute payoff
                    # back-propagate payoff to the root and break the loop
                    #todo: payoff (utility) can only be estimated here, since this
                    # is not the real terminal? => we need to compute the expected payoff
                    #
                    while len(stack) > 0:
                        r = stack.pop()
                    break
                # expand the tree
                stack.append(j)



