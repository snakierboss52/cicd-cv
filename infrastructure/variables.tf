variable "vpc_id" {
    type = string
    default = "vpc-07e4eae53490c5ad1" 
}

variable "subnets" {
    type = list(string)
    default = [ "subnet-064881b5071a96304" , "subnet-01337e6e80b2f251b" ]
}