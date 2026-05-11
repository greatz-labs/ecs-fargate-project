#!/bin/zsh

# Module files
for mod in vpc ecs alb ecr iam autoscaling; do
  touch ecs-fargate-project/modules/$mod/{main.tf,variables.tf,outputs.tf}
done
