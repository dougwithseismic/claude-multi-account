---
title: "Teams and organizations: which limits apply"
description: One login can belong to a personal plan and several Team or Enterprise organizations. Which limits a chat uses, and how to tell.
summary: Personal plans, Team seats, and which limits a chat uses.
order: 5
checked: "2026-10-19"
sources:
  - title: Find and join a Team or Enterprise organization (Claude Help Center)
    url: https://support.claude.com/en/articles/13566435-find-and-join-a-team-or-enterprise-organization
  - title: Log in to your Claude account (Claude Help Center)
    url: https://support.claude.com/en/articles/13189465-log-in-to-your-claude-account
  - title: What is the Team plan? (Claude Help Center)
    url: https://support.claude.com/en/articles/9266767-what-is-the-team-plan
  - title: Purchase and manage seats on Team plans (Claude Help Center)
    url: https://support.claude.com/en/articles/12004354-purchase-and-manage-seats-on-team-plans
  - title: What is the Enterprise plan? (Claude Help Center)
    url: https://support.claude.com/en/articles/9797531-what-is-the-enterprise-plan
  - title: Manage usage credits for Team and seat-based Enterprise plans (Claude Help Center)
    url: https://support.claude.com/en/articles/12005970
---

Your Claude login can belong to more than one organization: your personal account, plus any Team or Enterprise organizations you've joined. Each has its own plan and its own limits.

## Which limits a chat uses

The organization picked in the account menu. Switch to your company's Team and your chats use your seat's limits; switch back to personal and they use your personal plan's. Conversations and projects stay with the organization they were made in.

So using up your personal Pro limit doesn't touch your Team seat, and the other way round.

## Team seats are per person

On a Team plan, limits belong to each seat, not to the team as a whole. A premium seat has more than a standard one ([Plans](/learn/plans) has the sizes). Each seat belongs to one named person, and Anthropic says members can't send work through someone else's account to use its remaining usage.

When a seat reaches a limit, usage credits can carry it on at API rates if the organization has turned them on. That's the organization's choice, not the member's.

## Enterprise

Usage-based Enterprise plans have no plan or seat limits; the organization pays API rates for what's used. Older seat-based Enterprise plans have per-seat limits like Team's until they renew.

## How Claude Notch shows it

Each copy's row in the panel shows the organization that copy is working in, worked out from the organization Claude's own switcher picked. Below it is any other organization the login belongs to, marked **not in use**.

Claude only renews the login of the organization in use. So an organization you haven't used in a copy for a while shows **Switch Claude B to this organization to update**, and picking it once in that copy's account menu fixes it. An organization you've never used in a copy has no login there yet, and isn't shown. [Reading the panel](/docs/panel) lists every message.
