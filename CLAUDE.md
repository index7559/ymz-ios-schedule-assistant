# ymz-ios-schedule-assistant

## 项目概述

基于AI的个人本地日程管理应用，通过自然语言语音输入创建日程，数据存储在本地SQLite（GRDB）。

## 技术栈

- iOS客户端：SwiftUI + SFSpeechRecognizer + GRDB.swift
- 本地NLP：Apple NaturalLanguage框架（NLTag + regex）用于意图识别和日期解析
- LLM：ark-code-latest（火山方舟API），仅作为低置信度降级选项
- 存储：本地SQLite（通过GRDB.swift），无服务器端同步

## 项目结构

```
ios/  — iOS应用（SwiftUI）
```

## 开发命令

### iOS
```bash
cd ios && open *.xcodeproj
```

## 架构原则

- **双层解析**：NaturalLanguage框架（NLTag + regex）优先处理结构化输入，LLM API仅在低置信度时降级调用
- **离线优先**：核心意图识别和日期解析完全离线运行
- **本地存储**：所有数据存储在本地SQLite，无网络同步依赖

## Skill routing

- Architecture review → /plan-eng-review
- Design → /office-hours
- Ship → /ship
