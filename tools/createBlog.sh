#!/bin/bash
TITLE="$1"
DATE=$(date "+%Y-%m-%d")
BLOG_DATE=$(date "+%Y-%m-%d %H:%M:%S %z")
cat > "_posts/$DATE-$TITLE.md" << EOF
---
title: $TITLE
date: $BLOG_DATE
categories: [TOP_CATEGORY, SUB_CATEGORY]
tags: [TAG]     # TAG names should always be lowercase
---
EOF
