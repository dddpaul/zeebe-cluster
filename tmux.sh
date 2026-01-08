#!/bin/sh

session="zeebe"

attach() {
  [ -n "${TMUX:-}" ] &&
    tmux switch-client -t $session ||
    tmux attach-session -t $session
}

if tmux has-session -t "=$session" 2>/dev/null; then
  attach
  exit 0
fi

tmux new-session -d -s $session

# top panes
tmux split-window -v
tmux resize-pane -U 10
tmux select-pane -U
tmux split-window -h
tmux resize-pane -R 20
tmux split-window -h
tmux send-keys -t $session 'watch -n1 "kubectl top pods -A --sum=true -l \"app.kubernetes.io/instance in (camunda,redis,ingress,kibana)\" | awk \"{ printf \\\"%-21s %-12s %s\\\\n\\\", substr(\\\$2,1,20), \\\$3, \\\$4 }\""' Enter
tmux select-pane -L
tmux send-keys -t $session 'watch -n1 "kubectl get pods -A -l \"app.kubernetes.io/instance in (camunda,redis,ingress,kibana)\" -o custom-columns=\"NAME:.metadata.name,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount,NODE:.spec.nodeName\" | awk \"{ printf \\\"%-21s %-9s %-9s %s\\\\n\\\", substr(\\\$1,1,20), \\\$2, \\\$3, \\\$4 }\""' Enter
tmux select-pane -L
tmux send-keys -t $session 'docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"' Enter

# right pane
tmux select-pane -D
tmux split-window -h
tmux resize-pane -R 40
tmux send-keys -t $session 'watch -n1 "zbctl --insecure --address zeebe.camunda.home.arpa:26500 status"' Enter
tmux split-window -v
tmux send-keys -t $session 'watch -n1 "kubectl exec camunda-zeebe-0 -- du -h -d1 /usr/local/camunda/data/raft-partition/partitions/"' Enter

# move to bigger lower left pane
tmux select-pane -L

attach
