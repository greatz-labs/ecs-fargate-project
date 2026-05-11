variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "image_tag_mutability" {
  description = "IMMUTABLE prevents tag overwrites — use MUTABLE only if your CI doesn't produce unique tags"
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "Must be MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Run basic CVE scan on every image push"
  type        = bool
  default     = true
}

variable "max_image_count" {
  description = "Lifecycle policy: expire images once this many exist per repo"
  type        = number
  default     = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
