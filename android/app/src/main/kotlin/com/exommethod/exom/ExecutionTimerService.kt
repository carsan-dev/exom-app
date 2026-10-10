package com.exommethod.exom

/** Separate component: rest and execution never share a handler, player or run. */
class ExecutionTimerService : RestTimerService() {
    override val ongoingChannelId = "exom_execution_timer"
    override val finishedChannelId = "exom_execution_finished_v1"
    override val ongoingNotificationId = 41022
    override val finishedNotificationId = 41023
    override val titleResource = R.string.execution_timer_title
    override val countdownResource = R.string.execution_timer_countdown
    override val finishedTitleResource = R.string.execution_timer_finished_title
    override val finishedBodyResource = R.string.execution_timer_finished_body
    override val channelNameResource = R.string.execution_timer_channel_name
    override val channelDescriptionResource = R.string.execution_timer_channel_description
    override val finishedChannelNameResource = R.string.execution_timer_finished_channel_name
    override val finishedChannelDescriptionResource = R.string.execution_timer_finished_channel_description
    override val soundResource = R.raw.exom_execution_finished
    override val removeLegacyRestChannels = false
    override val suppressExpiredStart = true
}
