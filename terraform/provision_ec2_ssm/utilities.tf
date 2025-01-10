# Generate a random index to select a subnet name from the list
resource "random_integer" "subnet_index" {
  min = 0
  max = length(var.private_subnets) - 1
}
