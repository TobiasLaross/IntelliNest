//
//  Closures.swift
//  IntelliNest
//
//  Created by Tobias on 2022-10-07.
//

import Foundation

typealias VoidClosure = () -> Void
typealias MainActorVoidClosure = @MainActor () -> Void
typealias MainActorEntityIDClosure = @MainActor (EntityId) -> Void
typealias AsyncVoidClosure = () async -> Void
typealias MainActorAsyncVoidClosure = @MainActor () async -> Void
typealias StringClosure = (String) -> Void
typealias StringStringClosure = (String, String) -> Void
typealias DoubleClosure = (Double) -> Void
typealias IntClosure = (Int) -> Void
typealias HeaterDoubleClosure = @MainActor (HeaterEntity, Double) -> Void
typealias HeaterStringClosure = @MainActor (HeaterEntity, HvacMode) -> Void
typealias HeaterFanModeClosure = @MainActor (HeaterEntity, HeaterFanMode) -> Void
typealias FanModeClosure = (HeaterFanMode) -> Void
typealias HeaterHorizontalModeClosure = @MainActor (HeaterEntity, HeaterHorizontalMode) -> Void
typealias HorizontalModeClosure = (HeaterHorizontalMode) -> Void
typealias HeaterVerticalModeClosure = @MainActor (HeaterEntity, HeaterVerticalMode) -> Void
typealias VerticalModeClosure = (HeaterVerticalMode) -> Void
typealias EntityClosure = (Entity) -> Void
typealias MainActorEntityClosure = @MainActor (Entity) -> Void
typealias AsyncEntityClosure = (Entity) async -> Void
typealias ScriptIDClosure = (ScriptID) -> Void
typealias EntityIdDoubleClosure = @MainActor (EntityId, Double) -> Void
typealias AsyncLightClosure = (LightEntity) async -> Void
typealias AsyncSlideableClosure = @MainActor (Slideable) async -> Void
typealias SlideableIntClosure = @MainActor (Slideable, Int) -> Void
typealias AsyncSlideableIntClosure = (Slideable, Int) async -> Void
typealias DestinationClosure = (Destination) -> Void
