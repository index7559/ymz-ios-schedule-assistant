# ymz-ios-schedule-assistant

## 项目概述

AI日程管理应用，通过自然语言语音输入创建日程。

## 设计文档

设计文档位于：`ymz-ios-schedule-assistant-design-20260409-153000.md`

所有实现决策必须参考设计文档。

## 技术栈

- iOS客户端：SwiftUI + SFSpeechRecognizer + GRDB.swift
- 后端服务器：Node.js + Express + better-sqlite3
- LLM：ark-code-latest（火山方舟）

## 项目结构

```
ios/           — iOS应用（SwiftUI）
server/        — Node.js后端
```

## 开发命令

### 后端
```bash
cd server && npm install && node server/index.js
```

### iOS
```bash
cd ios && open *.xcodeproj
```

## Skill routing

- Architecture review → /plan-eng-review
- Design → /office-hours
- Ship → /ship
