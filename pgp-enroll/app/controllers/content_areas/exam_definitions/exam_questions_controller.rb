class ContentAreas::ExamDefinitions::ExamQuestionsController < ApplicationController
  before_filter :load_exam_models, :only => [:show, :answer]

  def show
    @answer_options = @exam_question.answer_options
  end

  def answer
    @answer_option = @exam_question.answer_options.find params[:answer_option_id]

    @question_reponse = QuestionResponse.new(
      :exam_response => @exam_response,
      :answer_option => @answer_option)

    if @question_reponse.save
      if @exam_question.last_in_exam?
        redirect_to content_area_exam_definition_path(@content_area, @exam_definition)
      else
        redirect_to content_area_exam_definition_exam_question_path(@content_area, @exam_definition, @exam_question.next_question)
      end
    else
      show and render :action => 'show'
    end
  end

  private

  def load_exam_models
    @content_area    = ContentArea.find params[:content_area_id]
    @exam_definition = @content_area.exam_definitions.find params[:exam_definition_id]
    @exam_response   = ExamResponse.find_by_user_id_and_exam_definition_id(current_user, @exam_definition)
    @exam_question   = @exam_definition.exam_questions.find params[:id]
  end
end
