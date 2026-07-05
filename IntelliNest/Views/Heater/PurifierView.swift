import SwiftUI

struct PurifierView: View {
    @State private var targetNumber: Double
    @Binding private var resetClimateTimeDate: Date

    let title: String
    let subtitle: String
    let fanEntityId: EntityId
    let maxLevel: Int
    let currentLevel: Double
    @Binding var resetClimateTimeEntity: Entity
    var isTimerModeEnabled: Bool
    let setFanSpeedClosure: DoubleClosure
    let toggleTimerModeClosure: VoidClosure
    let setClimateScheduleTimeClosure: MainActorEntityClosure

    var body: some View {
        ZStack {
            if isTimerModeEnabled {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.lightBlue.opacity(0.3), lineWidth: 4)
                    .frame(height: 200)
                    .padding(.horizontal, 4)
            }
            VStack {
                INText(title, font: .title)
                INText(subtitle, font: .subheadline)

                ZStack(alignment: .center) {
                    VStack {
                        NumberPickerScrollView(entityId: fanEntityId,
                                               targetNumber: $targetNumber,
                                               numberSelectedCallback: { _, targetNumber in
                                                   self.targetNumber = targetNumber
                                                   setFanSpeedClosure(targetNumber)
                                               },
                                               strideFrom: 0,
                                               strideTo: CGFloat(maxLevel + 1),
                                               strideStep: 1)
                            .padding(.vertical)
                    }

                    HStack {
                        Spacer()
                        VStack {
                            Button {
                                toggleTimerModeClosure()
                            } label: {
                                Image(systemImageName: .clock)
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(isTimerModeEnabled ? .lightBlue : .white)
                            }
                            if isTimerModeEnabled {
                                DatePicker("", selection: $resetClimateTimeDate, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                    .onChange(of: resetClimateTimeDate) {
                                        setClimateScheduleTimeClosure(resetClimateTimeEntity)
                                    }
                            }
                        }
                        .padding(.trailing, 270) // Space between Buttons and VStack
                        Spacer()
                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            targetNumber = currentLevel
        }
    }

    init(title: String,
         subtitle: String,
         fanEntityId: EntityId,
         maxLevel: Int,
         currentLevel: Double,
         resetClimateTimeEntity: Binding<Entity>,
         isTimerModeEnabled: Bool,
         setFanSpeedClosure: @escaping DoubleClosure,
         toggleTimerModeClosure: @escaping VoidClosure,
         setClimateScheduleTimeClosure: @escaping MainActorEntityClosure) {
        self.title = title
        self.subtitle = subtitle
        self.fanEntityId = fanEntityId
        self.maxLevel = maxLevel
        self.currentLevel = currentLevel
        _resetClimateTimeEntity = resetClimateTimeEntity
        _resetClimateTimeDate = resetClimateTimeEntity.date
        self.isTimerModeEnabled = isTimerModeEnabled
        self.setFanSpeedClosure = setFanSpeedClosure
        self.toggleTimerModeClosure = toggleTimerModeClosure
        self.setClimateScheduleTimeClosure = setClimateScheduleTimeClosure
        targetNumber = currentLevel
    }
}
