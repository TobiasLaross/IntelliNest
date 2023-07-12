//
//  Closures.swift
//  IntelliNest
//
//  Created by Tobias on 2022-10-07.
//

import Foundation

typealias VoidClosure = () -> Void
typealias AsyncVoidClosure = () async -> Void
typealias MainActorAsyncVoidClosure = @MainActor () async -> Void
typealias StringClosure = (String) -> Void
typealias DoubleClosure = (Double) -> Void
typealias HeaterDoubleClosure = (HeaterEntity, Double) -> Void
typealias HeaterStringClosure = (HeaterEntity, String) -> Void
typealias HeaterFanModeClosure = (HeaterEntity, FanMode) -> Void
typealias HeaterHorizontalModeClosure = (HeaterEntity, HorizontalMode) -> Void
typealias HeaterVerticalModeClosure = (HeaterEntity, HeaterVerticalPosition) -> Void
typealias EntityClosure = (Entity) -> Void
typealias AsyncEntityClosure = (Entity) async -> Void
typealias ScriptIDClosure = (ScriptID) -> Void
typealias EntityIdDoubleClosure = (EntityId, Double) -> Void
typealias AsyncLightClosure = (LightEntity) async -> Void
typealias AsyncSlideableClosure = (Slideable) async -> Void
typealias SlideableIntClosure = (Slideable, Int) -> Void
typealias AsyncSlideableIntClosure = (Slideable, Int) async -> Void
typealias DestinationClosure = (Destination) -> Void
