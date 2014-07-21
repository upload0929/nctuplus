class CoursesController < ApplicationController
  #before_filter :find_department, :only=>[ :index, :new, :edit]
  
  
	layout false, :only => [:list_all_courses, :search_by_keyword, :search_by_dept, :get_user_simulated, :get_user_courses, :get_sem_form, :get_user_statics]
	
	
	before_filter :checkLogin, :only=>[ :rate_cts, :simulation, :add_simulated_course]
	
	def index

		@semesters=Semester.all
		
		get_autocomplete_vars
		#@departments=Department.where("dept_type = 'dept' OR dept_type='common' ")#.merge(Department.where(:dept_type=>'common'))
		#@departments_all_select=@departments.map{|d| {"walue"=>d.id, "label"=>d.ch_name}}.to_json
		#@departments_grad_select=@departments.select{|d|d.degree=='2'}.map{|d| {"walue"=>d.id, "label"=>d.ch_name}}.to_json
		#@departments_under_grad_select=@departments.select{|d|d.degree=='3'}.map{|d| {"walue"=>d.id, "label"=>d.ch_name}}.to_json
		#@departments_common_select=@departments.select{|d|d.degree=='0'}.map{|d| {"walue"=>d.id, "label"=>d.ch_name}}.to_json
		
		#@degree_select=[{"walue"=>'3', "label"=>"大學部[U]"},{"walue"=>'2', "label"=>"研究所[G]"},{"walue"=>'0', "label"=>"大學部共同課程[C]"}].to_json
		
		@semester_select=Semester.all.select{|s|s.courses.count>0}.reverse.map{|s| {"walue"=>s.id, "label"=>s.name}}.to_json
		
		@view_type=""
		@preload_first_time=true;
  end
	
	def get_user_statics
		@css=current_user.course_simulations
		sem_ids=@css.map{|s|s.semester_id}
		@sems=Semester.where(:id=>sem_ids)
		#@cds=CourseDetail.where(:id=>cd_ids).order(:semester_id)
		@common_courses=@css.select{|cs|cs.course_detail.cos_type=="通識"}.map{|cs|cs.course_detail}
		#@common_courses=CourseDetail.where(:id=>cd_ids)
		render "statics"
	end
	
	def get_sem_form
		@user_sem_ids=current_user.course_simulations.map{|cs|cs.semester_id} 
		render "sem_form"
	end
	def get_user_courses 
		sem_id=params[:sem_id].to_i
		cd_ids=current_user.course_simulations.filter_semester(sem_id).map{|ps| ps.course_detail.id}
		@course_details=CourseDetail.where(:id=>cd_ids)
		#respond_to do |format|
    #  format.html # index.html.erb
    #  format.json { render json: @preschedules.map{|preschedule| preschedule.to_simulated } }
    #end
		if params[:type]=="schd"
			@cd_jsons=@course_details.map{|cd|{"time"=>cd.time,"color"=>cos_type_color(cd.cos_type),"room"=>cd.room,"name"=>cd.course_teachership.course.ch_name}}.to_json
			render "user_schedule"
		elsif params[:type]=="list"
			render "course_lists_mini"
		else 
			render ""
		end
	end
	
	def get_user_simulated
		@sem_id=params[:sem_id]
		get_autocomplete_vars
		@view_type="_mini"
		
		render "srch_and_schd"
	end
	
	def add_simulated_course
		cd_id=params[:cd_id].to_i
		_type=params[:type]
		sem_id=params[:sem_id]
		if _type=="add"
			CourseSimulation.create(:user_id=>current_user.id, :semester_id=>sem_id, :course_detail_id=>cd_id)
		else
			CourseSimulation.where(:user_id=>current_user.id, :course_detail_id=>cd_id).destroy_all
		end
		render :nothing => true, :status => 200, :content_type => 'text/html'
	end
	
	def list_all_courses
	  page=params[:page].to_i
		id_begin=(page-1)*each_page_show
		@course_details=CourseDetail.where(:id=>id_begin..id_begin+each_page_show)
		@course_details=@course_details.sort_by{|cd| cd.course_teachership.course_teacher_ratings.sum(:avg_score)}.reverse
		#@course_details=@courses
		@page_numbers=CourseDetail.all.count/each_page_show
	  render "course_lists"
	end
	
	def search_by_dept
		dept_id=params[:dept_id]
		semester_id=params[:sem_id].to_i
		
		dept_ids=get_dept_ids(dept_id)
		
		semester=Semester.where(:id=>semester_id).take
		if semester
			@courses=semester.courses.select{|c| join_dept(c,dept_ids)}
		
		else
			@courses=Course.where(:department_id=>dept_ids)
			#@course_details=@courses.
		end
			@course_details=join_course_detail(@courses,semester_id)
		
		@page_numbers=1#@course_details.count/each_page_show
		@table_type="search" if params[:view_type]=="_mini"
		render "course_lists"+params[:view_type]
	end
	
	def search_by_keyword
	  search_term=params[:search_term]
		search_type=params[:search_type]
		semester_id=params[:sem_id].to_i
		dept_id=params[:dept_id].to_i
		degree_id=params[:degree_id]
		if dept_id!=0
			dept_ids= get_dept_ids(dept_id)
		else
			dept_ids=Department.where(:degree=>degree_id.to_i).map{|d|d.id} if degree_id!=""
		end
		case search_type
			when "course_time"
				course_ids=[]
				cd_ids=[]
				#@course_details=nil
				search_term.split(' ').each do |st|
					st=st.upcase
					unless semester_id==0
						@cds=CourseDetail.where("semester_id= ? AND time LIKE ?  ",semester_id,"%#{st}%")
					else
						@cds=CourseDetail.where("time LIKE ?  ","%#{st}%")
					end
					ids=@cds.map{|cd|cd.id}
					cd_ids.append(ids) unless ids.empty?
					#course_ids.append(@cd.map{|cd|cd.course_teachership.course.id})
				end
				unless cd_ids.empty?
					@course_details=CourseDetail.where(:id=>cd_ids)
					@course_details=@course_details.select{|cd|join_dept(cd.course_teachership.course,dept_ids)} if dept_ids
				end
				#@courses=Course.where(:id=>course_ids)
				#@courses=@courses.select{|c| join_dept(c,dept_ids) } if dept_ids
				
			when "course_name"
				unless semester_id==0
					@courses = Course.where("id IN (:id) AND ch_name LIKE :name ",
						{:id=>SemesterCourseship.select("course_id").where(:semester_id=> semester_id), :name => "%#{search_term}%" })
				else
					@courses= Course.where("ch_name LIKE :name ",
																{:name => "%#{search_term}%" })#, :id=> SemesterCourseship.select("course_id").where(:semester_id=> "8"))		
				end
				if @courses
					@courses=@courses.select{|c| join_dept(c,dept_ids) } if dept_ids
					@course_details=join_course_detail(@courses,semester_id) unless @courses.empty? 
				end
		end
		
		@page_numbers=1#@course_details.count/each_page_show
		
		#	render
		#else
		@table_type="search" if params[:view_type]=="_mini"
		render "course_lists"+params[:view_type]
		#end
	end
	
	def rate_cts
    ctr_id=params[:ctr_id].to_i
		score=params[:score].to_i

		@ctr=CourseTeacherRating.find(ctr_id)#:course_teachership_id =>ctr_id, :rating_type=>type).take
		EachCourseTeacherRating.create(:score=>score, :user_id=>current_user.id, :course_teacher_rating_id=>@ctr.id)
		total_rating_counts=EachCourseTeacherRating.where(:course_teacher_rating_id=>@ctr.id).count
		total_rating_sum=EachCourseTeacherRating.where(:course_teacher_rating_id=>@ctr.id).sum(:score)
		@ctr.update_attributes(:total_rating_counts=>total_rating_counts, :avg_score=>total_rating_sum.to_f/total_rating_counts)
		
		result={:new_score=>@ctr.avg_score, :new_counts=>@ctr.total_rating_counts}
		respond_to do |format|
			format.html {
				render :json => result.to_json,
							 :content_type => 'text/html',
							 :layout => false
			}
		end
	end
	
  def show
    @course = Course.find(params[:id])
		@posts = @course.posts
		@post= Post.new #for create course form
		@files=@course.file_infos
		#course_details_tids=CourseDetail.where(:course_id=>@course.id).uniq.pluck(:teacher_id)
		
		# for _teacher_info.html.erb
		@teachers=@course.teachers.sort_by{
			|cd| CourseTeachership.where(:course_id=>params[:id],:teacher_id=>cd.id).first.course_teacher_ratings.sum(:avg_score) 
		}.reverse
		if params[:tid]
			@teacher_show =  Teacher.find(params[:tid])
			@target_rank = -1 ;
			@teachers.each_with_index do | teacher, idx|
				if teacher.id == @teacher_show.id
					@target_rank = idx+1
					break ;
				end
			end
		else
			@teacher_show =  @teachers.first
			@target_rank = 1 
		end
		# course_teacherships.where(:course_id=>params[:id]).course_teacher_ratings
		@sems=@course.semesters
	#@teachers=Teacher.where(:course_id=>@course.id)
  end
	
	def simulation
    #@semesters=Semester.all	
		
		#@departments=Department.where(:dept_type=>'dept')
		#@departments_all_select=@departments.map{|d| {"walue"=>d.id, "label"=>d.ch_name}}.to_json
		#@departments_grad_select=@departments.select{|d|d.degree=='2'}.map{|d| {"walue"=>d.id, "label"=>d.ch_name}}.to_json
		#@departments_under_grad_select=@departments.select{|d|d.degree=='3'}.map{|d| {"walue"=>d.id, "label"=>d.ch_name}}.to_json
		#@departments_common_select=@departments.select{|d|d.degree=='0'}.map{|d| {"walue"=>d.id, "label"=>d.ch_name}}.to_json
		
		#@degree_select=[{"walue"=>'3', "label"=>"大學部[U]"},{"walue"=>'2', "label"=>"研究所[G]"},{"walue"=>'0', "label"=>"大學部共同課程[C]"}].to_json
		
		#@semester_select=Semester.all.select{|s|s.courses.count>0}.map{|s| {"walue"=>s.id, "label"=>s.name}}.to_json
		@user_sem_ids=current_user.course_simulations.map{|cs|cs.semester_id} 
		#@user_sem_ids.append(Semester.last.id)
		
		
  end
	
  def new
    @course=@department.courses.build
  end
	
  #def create
  #  @course = Course.new(course_param)
  #  @course.save
  #  redirect_to :action => :index
  #end
	
  def edit
    @course = Course.find(params[:id])
  end
	
  def update
    @course = Course.find(params[:id])
	
    @course.ch_name=params[:course][:ch_name]
		@course.eng_name=params[:course][:eng_name]
    @course.save!
    redirect_to :action => :show, :id => @course
  end
	
  def destroy
    @course = Course.find(params[:id])
    @course.destroy

    redirect_to :action => :index
  end
  
  protected
  def find_department
    @department=Department.find(params[:department_id])
  end
  
  
  private
	
	
	
	def cos_type_color(cos_type)
		case cos_type
			when "通識"
				'#f0ad4e'
			when "必修"
				'#AFFFB0'
			when "選修"
				'#AFFFD8'
			when "外語"
				'#FEFFCD'
		end
	end
	
	
	def get_autocomplete_vars
		@departments=Department.where("dept_type = 'dept' OR dept_type='common' ")#.merge(Department.where(:dept_type=>'common'))
		@departments_all_select=@departments.map{|d| {"walue"=>d.id, "label"=>d.ch_name}}.to_json
		@departments_grad_select=@departments.select{|d|d.degree=='2'}.map{|d| {"walue"=>d.id, "label"=>d.ch_name}}.to_json
		@departments_under_grad_select=@departments.select{|d|d.degree=='3'}.map{|d| {"walue"=>d.id, "label"=>d.ch_name}}.to_json
		@departments_common_select=@departments.select{|d|d.degree=='0'}.map{|d| {"walue"=>d.id, "label"=>d.ch_name}}.to_json
		@degree_select=[{"walue"=>'3', "label"=>"大學部[U]"},{"walue"=>'2', "label"=>"研究所[G]"},{"walue"=>'0', "label"=>"大學部共同課程[C]"}].to_json
	end
	def join_course_detail(courses,semester_id)
		course_ids=courses.map{|c| c.id}
		ct_ids=CourseTeachership.where(:course_id=>course_ids)#@courses.map{|c|c.course_teacherships.map{|ct| ct.id}}
		if semester_id!=0
			course_details=CourseDetail.where(:course_teachership_id=>ct_ids).flit_semester(semester_id)
		else
			course_details=CourseDetail.where(:course_teachership_id=>ct_ids)
		end
		return course_details
	end
	
	def get_dept_ids(dept_id)
	  return nil if dept_id==0
		
	  dept_ids=[]
		dept_main=Department.where(:id=>dept_id).take
		dept_ids.append(dept_main.id)
		dept_college=Department.where(:degree => dept_main.degree, :college_id=>dept_main.college_id, :dept_type => 'college').take
		dept_ids.append(dept_college.id) if !dept_college.nil?
		return dept_ids
	end
	
	def join_dept(course,dept_ids)
		dept_ids.each do |dept_id|
		  return true if course.department_id==dept_id
		end
		return false
	end
	
	def each_page_show
	  30
	end
	
  def course_param
		params.require(:course).permit(:ch_name, :eng_name, :department_id)
  end
  
end