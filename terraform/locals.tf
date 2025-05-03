locals {
  # Master node must be first at the list and keep the same name
  node_names     = ["master", "worker1", "worker2"]
  worker_indexes = [for idx, name in local.node_names : idx if name != "master"]
}