class DispatchMessenger
  def initialize(responder)
    @responder = responder
    @dispatch  = responder.dispatches.first
    @report    = @dispatch.report unless @dispatch.blank?
  end

  def respond(body)
    feedback, status = true, nil
    if @responder.shifts.started? && body[/break/i]
      @responder.shifts.end('sms') && feedback = false if breaktime
      status = 'rejected' if @dispatch && @dispatch.pending?
    elsif !@responder.shifts.started? && body[/on/i]
      @responder.shifts.start('sms') && feedback = false
    elsif @dispatch.pending? && body[/no/i]
      status = 'rejected'
    elsif @dispatch.accepted? && body[/done/i]
      status = 'completed'
    elsif @dispatch.pending?
      status = 'accepted'
    end
    # If dispatch changed then update status
    @dispatch.update_attributes(status: status) if status
    # Send log if there is a need for feedback
    @report.logs.create(author: @responder, body: body) if feedback
  end

  def trigger
    case @dispatch.status
    when 'accepted'
      accept
    when 'completed'
      complete
    when 'pending'
      pending
    when 'rejected'
      reject
    end
  end

  private

  def accept
    @dispatch.accept
    accept_dispatch_notification
    acknowledge_acceptance
    notify_about_primary_responder
    notify_reporter
  end

  def complete
    thank_responder
    thank_reporter
  end

  def pending
    Telephony.send(responder_synopses, @responder.phone)
  end

  def reject
    if @responder.shifts.started?
      acknowledge_rejection
    else
      acknowledge_break
    end
  end

  def accept_dispatch_notification
    @report.logs.create(
      author: @responder, body: '--- Accepted the dispatch ---'
    )
  end

  def acknowledge_acceptance
    Telephony.send(
      "You have been assigned to an incident at #{@report.address}.",
      @responder.phone
    )
  end

  def acknowledge_rejection
    message = <<-MSG
      You have been removed from this incident at #{@report.address}. You are now available to be dispatched.
    MSG
    Telephony.send(message, @responder.phone)
  end

  def acknowledge_break
    message = <<-MSG
      You have been removed from this incident at #{@report.address}. Please text 'On' when ready to return to your shift.
    MSG
    Telephony.send(message, @responder.phone)
  end

  def breaktime
    @dispatch.nil? || @dispatch.completed? || @dispatch.pending? || @dispatch.rejected?
  end

  def notify_reporter
    Telephony.send(reporter_synopsis, @report.phone)
  end

  def notify_about_primary_responder
    return false unless @report.multi_accepted_responders?
    message = <<-MSG
      The primary responder for this report is: #{@report.primary_responder.name} – #{@report.primary_responder.phone}
    MSG
    Telephony.send(message, @responder.phone)
  end

  def reporter_synopsis
    if @report.multi_accepted_responders?
      <<-MSG
        Additional Support: #{@responder.name} is on the way to help #{@report.primary_responder.name}.
      MSG
    elsif @report.agency.present? && @report.agency.call_phone.present?
      agency = @report.agency
      "Incident Response: #{@responder.name} is on the way. Contact the #{agency.name} at #{agency.call_phone}"
    else
      "Incident Response: #{@responder.name} is on the way. #{@responder.phone}"
    end
  end

  def responder_synopses
    [
      @report.address,
      "Reporter: #{[@report.name, @report.phone].delete_blank * ', '}",
      "#{[@report.race, @report.gender, @report.age].delete_blank * '/'}",
      @report.setting,
      @report.nature,
      @report.urgency
    ].delete_blank * ' | '
  end

  def thank_responder
    message = <<-EOF
      The report is now completed, thanks for your help! You are now available to be dispatched.
    EOF
    Telephony.send(message, @responder.phone)
  end

  def thank_reporter
    Telephony.send('Report resolved, thanks for being concrned!', @report.phone)
  end
end
