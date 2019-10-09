# Get Ubuntu 18.04 base image
FROM ubuntu:18.04

# Run the Update
RUN apt-get update && apt-get upgrade -y

# Install pre-reqs
RUN apt-get install -y python curl openssh-server

# Setup sshd
# RUN mkdir -p /var/run/sshd
# RUN echo 'root:password' | chpasswd
# RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# download and install pip
RUN curl -sO https://bootstrap.pypa.io/get-pip.py
RUN python get-pip.py

# install AWS CLI
RUN pip install awscli

# Setup AWS CLI Command Completion
RUN echo complete -C '/usr/local/bin/aws_completer' aws >> ~/.bashrc

# Label the instance
LABEL com.github.actions.name="NodeJS Deploy AWS Serverless"
LABEL com.github.actions.description="Deploy your NodeJS app to AWS Serverless"
LABEL com.github.actions.icon="code"
LABEL com.github.actions.color="red"

# Set the maintainer
LABEL maintainer="GitHub DevOps <github_devops@github.com>"

# Copy files to container
COPY lib /action/lib

# Set the entrypoint
ENTRYPOINT ["/action/lib/entrypoint.sh"]
