# Highly Available Web Application IaC Deployment

## Introduction
This project aims to create a highly available web application that is fault-tolerant and able to scale continuously with user usage. In this project, a WordPress application is developed so that the application server, database, and file server tiers can scale independently. The application's components will be deployed into two availability zones to protect it against failure of any one availability zone. The WordPress application will be deployed statelessly so that web application servers can be added or removed automatically in response to the requests flowing into the system.


## Libraries and Skills Used
- Terraform
- AWS VPC
- Networking and Security protocols
- AWS RDS
- AWS EFS
- AWS Autoscale
- AWS Load Balancer
- Well-Architected Framework


## Method
This work is based on the efforts completed in [this workshop](https://catalog.us-east-1.prod.workshops.aws/workshops/3de93ad5-ebbe-4258-b977-b45cdfe661f1/en-US)

Firstly, I used AWS VPC to create a software-defined network across multiple AWS availability zones in a single AWS region.

Using Amazon RDS I created a managed active / standby multi-node MySQL database deployment that is automatically backed up and recoverable within the last 5 minutes and is patched on my behalf. In the event of a failure, the database will automatically failover to the standby node which is synchronously replicated with the active node, ensuring you never lose your data.

Then I created a distributed file system using Amazon Elastic Filesystem (EFS) to share WordPress content among multiple application servers.

Finally, using AWS Auto Scaling and the AWS Application Load Balancer I created a fleet of instances that automatically scales in and out based on resource utilization of my application server. As new servers come online the load balancer will automatically be updated with their information, as servers are removed the auto-scaling group will inform the load balancer and drain connections from those servers.

All of this produces a highly available, distributed, and fault-tolerant web application. A diagram of all the components together can be seen below.

![webapp_architecture_diagram drawio (1)](https://github.com/aziz66710/web-app/assets/65475783/85d566b6-67c2-4b39-bbcf-d96361517a63)



