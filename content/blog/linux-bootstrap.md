---
title: Linux Bootstrap
date: 2026-06-18
draft: true
---

After the hard drive on my Windows 10 home PC crashed, I decided to return to Linux on the desktop.
I've been using Linux for 25+ years, including Slackware, Fedora Core, and finally settling
on Ubuntu. Since 2017, I've been using Windows on the desktop while continuing to use Ubuntu
for web hosting. Hard drives crashes prompt me to do two things 1) review my backup strategy so that
I don't lose anything important next time, and 2) automate PC setup as much as possible for the next time.

Over the years with server setup, I've used a combination of a runbook document and Ansible. The runbook
document reminds me what to do, in what order, and copy/pasting commands when possible, but it's manual.
Ansible playbooks are more automated, but also more work to maintain and it requires some initial setup
to run.

This is the fresh install problem: install git, create an ssh key, register it with github, clone the
Ansible setup repo, install ansible, all in order to automate the setup.

Two theses: How has Ubuntu changed. Use bootstrap.sh
- Apt, snap, flatpak
Future: doc.sh
