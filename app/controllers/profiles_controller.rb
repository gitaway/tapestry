class ProfilesController < ApplicationController

  skip_before_filter :login_required, :only => [:public]
  skip_before_filter :ensure_enrolled, :only => [:public]

  include PhrccrsHelper

  def public
    @user = User.publishable.find_by_hex(params[:hex])

    # Invalid hex code
    return if @user.nil?

    @page_title = @user.hex

    @confirmed_family_relations = @user.confirmed_family_relations

    @ccr = @user.ccrs.latest

    survey = Survey.find(:first, :conditions => { :name => 'Absolute Pitch Survey' });
    @absolute_pitch_questions = []
    @absolute_pitch_questions = survey.survey_sections[0].survey_questions if not survey.nil? and not survey.survey_sections.nil?
    @absolute_pitch_answers = {}
    absolute_pitch_answer_mapping = { 'y' => 'Yes', 'n' => 'No', 'ns' => 'Not sure', 'na' => 'Not available', 13 => '>12' }
    @user.survey_answers.each {|a|
      if @absolute_pitch_answers[a.survey_question_id].nil?
        @absolute_pitch_answers[a.survey_question_id] = absolute_pitch_answer_mapping[a.text]
      end
    }
    nonces = Nonce.where(:owner_class => "User", :owner_id => @user.id, :target_class => "GoogleSurvey")
    @google_survey_results = []
    nonces.each {|n|
      response = {}
      response[:nonce] = n.id
      response[:collected_at] = n.used_at
      response[:survey] = GoogleSurvey.find(n.target_id)
      next if !response[:survey].is_result_public?
      response[:answers] = GoogleSurveyAnswer.find_all_by_nonce_id(n.id).select { |x| !x.google_survey_question.is_hidden }
      next if response[:answers].empty?
      response[:qa] = []
      response[:answers].each do |answer|
        if answer.answer and answer.column != response[:survey].userid_response_column
          response[:qa].push [answer.google_survey_question.question, answer.answer]
          response[:timestamp] = answer.answer if answer.google_survey_question.question == 'Timestamp'
        end
      end
      @google_survey_results.push response
    }

    TraitwiseSurvey.where(:is_result_public => true).each do |tws|
      sheet = tws.spreadsheet
      response = {
        :survey => tws,
        :collected_at => [],
        :nonce => "tws_sheet_#{sheet.id}",
        :qa => []
      }
      @user.spreadsheet_rows.where('spreadsheet_id = ?', sheet.id).each do |sr|
        qa = []
        (0..sheet.header_row.length-1).to_a.each do |i|
          case sheet.header_row[i]
          when 'Question Body'
            qa[0] = sr.row_data[i]
          when 'Responses'
            qa[2] = sr.row_data[i]
          when 'Numeric Answer'
            qa[1] = qa[2].split('||')[sr.row_data[i].to_i] if qa[2]
          when 'Text Answer'
            qa[1] = sr.row_data[i] unless sr.row_data[i].empty?
          end
        end
        response[:qa].push qa
        response[:collected_at].push sr.updated_at
      end

      # hide all but the latest answer to each question
      have_later_answer = {}
      response[:qa] = response[:qa].reverse.select { |qa|
        have_later_answer[qa[0]] ||= 0
        (have_later_answer[qa[0]] += 1) == 1
      }.reverse

      # hide questions with empty answers ("skip this question")
      response[:qa].reject! do |qa|
        qa[1].nil? or qa[1] == ''
      end

      unless response[:qa].empty?
        response[:collected_at] = response[:collected_at].max
        @google_survey_results.push response
      end
    end

    # make a 2D array of samples: @sample_groups[N] will be an array containing all samples from one study
    @sample_groups = []
    @user.samples.sort { |a,b| a.study_id <=> b.study_id or a.id <=> b.id }.each do |s|
      next unless s.parent_samples.empty? # skip derived samples
      if @sample_groups.empty? or @sample_groups[-1][0].study != s.study
        @sample_groups.push []
      end
      @sample_groups[-1].push s
    end

    @user_files_and_datasets = (@user.published_datasets | @user.user_files).sort do |a,b|
      a_date = (a.respond_to?(:date) && a.date) ? Time.parse(a.date.to_s) : a.published_at
      b_date = (b.respond_to?(:date) && b.date) ? Time.parse(b.date.to_s) : b.published_at
      b_date <=> a_date
    end
  end
end
