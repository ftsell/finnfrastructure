// General traffic
module "main_ip" {
  source       = "./service_ip"
  service_name = "main"
  srv_id       = hcloud_server.main.id
}
output "main_ip" {
  value = module.main_ip.ip_address
}
