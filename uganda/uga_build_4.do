* Project: WB COVID
* Created on: July 2020
* Created by: jdm
* Edited by : amf
* Last edited: December 2020
* Stata v.16.1

* does
	* reads in fourth round of Uganda data
	* builds round 4
	* outputs round 4

* assumes
	* raw Uganda data

* TO DO:
	* complete


* **********************************************************************
* 0 - setup
* **********************************************************************

* define
	global	root	=	"$data/uganda/raw"
	global	fies	=	"$data/analysis/raw/Uganda"
	global	export	=	"$data/uganda/refined"
	global	logout	=	"$data/uganda/logs"

* open log
	cap log 		close
	log using		"$logout/uga_build", append
	
* set local wave number & file number
	local			w = 4
	
* make wave folder within refined folder if it does not already exist 
	capture mkdir "$export/wave_0`w'" 	
	

* ***********************************************************************
* 1 - reshape section 6 wide data
* ***********************************************************************

* load income data
	use				"$root/wave_0`w'/SEC6", clear

* drop 
	drop 			interview__key s6q01_Other
	
* reformat HHID
	format 			%12.0f HHID

* replace value for "other"
	replace			income_loss__id = 96 if income_loss__id == -96

* reshape data
	reshape 		wide s6q01 s6q02 s6q03, i(HHID) j(income_loss__id)

* save temp file
	tempfile		temp1
	save			`temp1'


* ***********************************************************************
* 2 - reshape section 10 wide data 
* ***********************************************************************

* load safety net data - updated via convo with Talip 9/1
	use				"$root/wave_0`w'/SEC10", clear

* reformat HHID
	format 			%12.0f HHID

* drop other safety nets and missing values
	drop			s10q02 s10q03__1 s10q03__2 s10q03__3 s10q03__4 ///
						s10q03__5 s10q03__6 s10q03__n96 s10q03_Other ///
						other_nets

* reshape data
	reshape 		wide s10q01, i(HHID) j(safety_net__id)
	*** note that cash = 102, food = 101, in-kind = 103 (unlike wave 1)

* rename variables
	gen				asst_food = 1 if s10q01101 == 1
	replace			asst_food = 0 if s10q01101 == 2
	replace			asst_food = 0 if asst_food == .
	lab var			asst_food "Recieved food assistance"
	lab def			assist 0 "No" 1 "Yes"
	lab val			asst_food assist
	
	gen				asst_cash = 1 if s10q01102 == 1
	replace			asst_cash = 0 if s10q01102 == 2
	replace			asst_cash = 0 if asst_cash == .
	lab var			asst_cash "Recieved cash assistance"
	lab val			asst_cash assist
	
	gen				asst_kind = 1 if s10q01103 == 1
	replace			asst_kind = 0 if s10q01103 == 2
	replace			asst_kind = 0 if asst_kind == .
	lab var			asst_kind "Recieved in-kind assistance"
	lab val			asst_kind assist
	
	gen				asst_any = 1 if asst_food == 1 | asst_cash == 1 | ///
					asst_kind == 1
	replace			asst_any = 0 if asst_any == .
	lab var			asst_any "Recieved any assistance"
	lab val			asst_any assist

* drop variables
	drop			s10q01101 s10q01102 s10q01103
	
* save temp file
	tempfile		temp2
	save			`temp2'


* ***********************************************************************
* 3 - get respondant gender
* ***********************************************************************

* load data
	use				"$root/wave_0`w'/interview_result", clear

* drop all but household respondant
	keep			HHID Rq09

	rename			Rq09 hh_roster__id

	isid			HHID

* merge in household roster
	merge 1:1		HHID hh_roster__id using "$root/wave_0`w'/SEC1.dta"

	keep if			_merge == 3

* rename variables and fill in missing values
	rename			hh_roster__id PID
	rename			s1q05 sex
	rename			s1q06 age
	rename			s1q07 relate_hoh
	drop if			PID == .

* drop all but gender and relation to HoH
	keep			HHID PID sex age relate_hoh

* save temp file
	tempfile		temp3
	save			`temp3'

	
* ***********************************************************************
* 4 - get household size and gender of HOH
* ***********************************************************************

* load data
	use				"$root/wave_0`w'/SEC1.dta", clear

* rename other variables 
	rename 			hh_roster__id ind_id 
	rename 			s1q03 curr_mem
	replace 		curr_mem = 1 if s1q02 == 1
	rename 			s1q05 sex_mem
	rename 			s1q06 age_mem
	rename 			s1q07 relat_mem

* generate counting variables
	gen				hhsize = 1 if curr_mem == 1
	gen 			hhsize_adult = 1 if curr_mem == 1 & age_mem > 18 & age_mem < .
	gen				hhsize_child = 1 if curr_mem == 1 & age_mem < 19 & age_mem != . 
	gen 			hhsize_schchild = 1 if curr_mem == 1 & age_mem > 4 & age_mem < 19 
	
* create hh head gender
	gen 			sexhh = . 
	replace			sexhh = sex_mem if relat_mem == 1
	label var 		sexhh "Sex of household head"

* generate migration vars
	rename 			s1q02 new_mem
	replace 		new_mem = 0 if new_mem >= .
	replace 		new_mem = 0 if s1q08 == 10
	replace 		s1q08 = . if s1q08 == 10
	replace 		curr_mem = 2 if curr_mem >= .
	gen 			mem_left = 1 if curr_mem == 2
	replace 		new_mem = 0 if new_mem == 2
	replace 		mem_left = 0 if mem_left == 2
	
* collapse data
	collapse		(sum) hhsize hhsize_adult hhsize_child hhsize_schchild new_mem mem_left ///
						(max) sexhh, by(HHID)
	lab var			hhsize "Household size"
	lab var 		hhsize_adult "Household size - only adults"
	lab var 		hhsize_child "Household size - children 0 - 18"
	lab var 		hhsize_schchild "Household size - school-age children 5 - 18"
	lab var 		mem_left "Member of household left since last call"
	lab var 		new_mem "Member of household joined since last call"
	
* save temp file
	tempfile		temp4
	save			`temp4'

	
* ***********************************************************************
* 5 - FIES
* ***********************************************************************

* load data
	use				"$fies/UG_FIES_round`w'.dta", clear

	drop 			country round
	destring 		HHID, replace

* save temp file
	tempfile		temp5
	save			`temp5'

	
* ***********************************************************************
* 6 - education 
* ***********************************************************************
 
* generate sch_att = 1 if any child attending school
	use				"$root/wave_0`w'/SEC1.dta", clear
	keep 			if s1cq01 == 1
	replace 		s1cq03 = 0 if s1cq03 == 2
	collapse		(sum) s1cq03, by(HHID)
	gen 			sch_att = 1 if s1cq03 > 0 
	replace 		sch_att = 0 if sch_att  == .
	keep 			HHID sch_att 
	tempfile 		tempsch
	save 			`tempsch'
	
* generate edu_act = 1 if any child engaged in learning activities
	use				"$root/wave_0`w'/SEC1.dta", clear
	keep 			if s1cq01 == 1
	replace 		s1cq09  = 0 if s1cq09  == 2
	collapse		(sum) s1cq09, by(HHID)
	gen 			edu_act = 1 if s1cq09 > 0 
	replace 		edu_act = 0 if edu_act == .
	keep 			HHID edu_act
	tempfile 		tempany
	save 			`tempany'

* rename other variables 
	* sch_att_why
	use				"$root/wave_0`w'/SEC1.dta", clear	
	keep 			if s1cq03 == 2
	forval 			x = 1/15 {
	    rename 		s1cq04__`x' sch_att_why_`x'
	}		
	collapse 		(sum) sch* , by(HHID)
	forval 			x = 1/15 {
	    replace 		sch_att_why_`x' = 1 if sch_att_why_`x' >= 1
	}	
	tempfile 		tempattwhy
	save 			`tempattwhy'
	
	* sch_prec
	use				"$root/wave_0`w'/SEC1.dta", clear	
	keep 			if s1cq03 == 1
	forval 			x = 1/11 {
	    rename 		s1cq07__`x' sch_prec_`x'
	}
	rename 			s1cq07__n99 sch_prec_none
	collapse 		(sum) sch* , by(HHID)
	forval 			x = 1/11 {
	    replace 		sch_prec_`x' = 1 if sch_prec_`x' >= 1
	}
	replace 		sch_prec_none = 1 if sch_prec_none >= 1
	tempfile 		tempprec
	save 			`tempprec'
	
	* edu_act_why
	use				"$root/wave_0`w'/SEC1.dta", clear
	keep 			if s1cq09 == 2
	forval 			x = 1/11 {
		rename 		s1cq10__`x' edu_act_why_`x'
	}
	collapse 		(sum) edu* , by(HHID)
	forval 			x = 1/11 {
		replace 		edu_act_why_`x' = 1 if edu_act_why_`x' >= 1
	}
	tempfile 		tempactwhy
	save 			`tempactwhy'
		
	* edu & edu_chal
	use				"$root/wave_0`w'/SEC1.dta", clear
	keep 			if s1cq09 == 1
	rename 			s1cq11__1 edu_1
	rename 			s1cq11__2 edu_2
	rename 			s1cq11__3 edu_3
	rename 			s1cq11__4 edu_4
	rename 			s1cq11__5 edu_5
	rename 			s1cq11__6 edu_8
	rename 			s1cq11__7 edu_9
	rename 			s1cq11__8 edu_10
	rename 			s1cq11__9 edu_11
	rename 			s1cq11__10 edu_12
	rename 			s1cq11__11 edu_7
	rename 	 		s1cq11__n96 edu_other
	forval 			x = 1/13 {
	    replace 	s1cq12__`x' = 0 if s1cq12__`x' == 2
	    rename 		s1cq12__`x' edu_chal_`x'
	}
	collapse 		(sum) edu* , by(HHID)
	ds edu* 
	foreach 		var in `r(varlist)' {
	    replace 		`var' = 1 if `var' >= 1
	}
	tempfile 		tempedu
	save 			`tempedu'
	
* merge data together 
	use				"$root/wave_0`w'/SEC1.dta", clear
	keep 			HHID 
	duplicates 		drop
	merge 			1:1 HHID using `tempsch', nogen
	merge 			1:1 HHID using `tempany', nogen
	merge			1:1 HHID using `tempattwhy', nogen
	merge 			1:1 HHID using `tempprec', nogen
	merge 			1:1 HHID using `tempactwhy', nogen
	merge 			1:1 HHID using `tempedu', nogen

* save temp file
	tempfile		temp6
	save			`temp6'

		
* ***********************************************************************
* 7 - build uganda cross section
* ***********************************************************************

* load cover data
	use				"$root/wave_0`w'/Cover", clear
	
* merge in other sections	
	forval 			x = 1/6 {
	    merge 		1:1 HHID using `temp`x'', nogen
	}
	merge 1:1 		HHID using "$root/wave_0`w'/SEC2.dta", nogen
	merge 1:1 		HHID using "$root/wave_0`w'/SEC3.dta", nogen
	merge 1:1 		HHID using "$root/wave_0`w'/SEC4.dta", nogen
	merge 1:1 		HHID using "$root/wave_0`w'/SEC5.dta", nogen
	merge 1:1 		HHID using "$root/wave_0`w'/SEC5A.dta", nogen
	merge 1:1 		HHID using "$root/wave_0`w'/SEC5B.dta", nogen 
	merge 1:1 		HHID using "$root/wave_0`w'/SEC8.dta", nogen
	merge 1:1 		HHID using "$root/wave_0`w'/SEC9.dta", nogen	
	
* reformat HHID
	format 			%12.0f HHID

* rename variables inconsistent with other waves
	* rename govt action
		rename 			s2gq05 mask 
	* rename behavioral changes
		rename			s3q01 bh_1
		rename			s3q02 bh_2
		rename			s3q03 bh_3
		rename			s3q04 bh_4
		rename			s3q05 bh_5
		rename			s3q06 bh_freq_wash
		rename			s3q07_1 bh_freq_mask_oth
		rename 			s3q08 bh_freq_gath
	* vaccines
		rename 			s4q15 cov_test
		rename 			s4q16 cov_vac
		rename 			s4q17__1 cov_vac_no_why_1
		rename 			s4q17__2 cov_vac_no_why_2
		rename 			s4q17__3 cov_vac_no_why_3
		rename 			s4q17__4 cov_vac_no_why_6
		rename 			s4q17__5 cov_vac_no_why_4
		rename 			s4q17__6 cov_vac_no_why_5			
		rename 			s4q18__1 cov_vac_dk_why_1
		rename 			s4q18__2 cov_vac_dk_why_2
		rename 			s4q18__3 cov_vac_dk_why_3
		rename 			s4q18__4 cov_vac_dk_why_6
		rename 			s4q18__5 cov_vac_dk_why_4
		rename 			s4q18__6 cov_vac_dk_why_5
		drop 			s4q18__n96 s4q17__n96
	* rename employment
		rename			s5q01 emp
		rename			s5q01a rtrn_emp
		rename			s5q01b rtrn_emp_when
		rename			s5q01c emp_why
		rename 			s5q03 emp_pre_why
		rename			s5q03a emp_search
		rename			s5q03b emp_search_how
		rename			s5q04a emp_same
		rename			s5q04b emp_chg_why
		rename			s5q05 emp_act
		rename			s5q06 emp_stat
		replace 		emp_stat = 100 if emp_stat == 5
		replace 		emp_stat = 5 if emp_stat == 6
		replace 		emp_stat = 6 if emp_stat == 100
		rename 			s5q06a emp_purp
		rename			s5q07 emp_able
		rename			s5q08 emp_unable
		rename			s5q08a emp_unable_why
		rename			s5q08b emp_hrs
		rename			s5q08c emp_hrs_chg
		rename			s5q08f_* emp_saf*
		rename 			emp_saf_n96 emp_saf_96
		rename 			s5q08g emp_saf_fol
		rename 			s5q08g_1 emp_saf_fol_per
		rename			s5q09 emp_hh
	* non-farm income
		rename			s5aq11 bus_emp	
		rename			s5aq11a bus_stat
		rename 			s5aq11b_1 bus_other
		rename			s5aq12 bus_sect
		rename			s5aq12_1 bus_sect_oth
		rename			s5aq13 bus_emp_inc
		rename			s5aq14_1 bus_why
	* rename agriculture
		rename			s5bq16 ag_crop
		rename			s5bq17 ag_plan	
		rename			s5bq17_1__1 ag_nocrop_1
		rename			s5bq17_1__2 ag_nocrop_2
		rename			s5bq17_1__3 ag_nocrop_3
		rename			s5bq17_1__4 ag_nocrop_4
		rename			s5bq17_1__5 ag_nocrop_10
		rename			s5bq17_1__6 ag_nocrop_5
		rename			s5bq17_1__7 ag_nocrop_6
		rename			s5bq17_1__8 ag_nocrop_7
		rename 			s5bq18_1 ag_crop_1
		rename 			s5bq18_2 ag_crop_2
		rename 			s5bq18_3 ag_crop_3
		rename 			s5bq19 ag_chg
		rename			s5bq20__1 ag_chg_1
		rename			s5bq20__2 ag_chg_2
		rename			s5bq20__3 ag_chg_3
		rename			s5bq20__4 ag_chg_4
		rename			s5bq20__5 ag_chg_5
		rename			s5bq20__6 ag_chg_6
		rename			s5bq20__7 ag_chg_7
		rename			s5bq21__1 ag_covid_1
		rename			s5bq21__3 ag_covid_3
		rename			s5bq21__4 ag_covid_4
		rename			s5bq21__5 ag_covid_5
		rename			s5bq21__6 ag_covid_6
		rename			s5bq21__7 ag_covid_7
		rename			s5bq21__8 ag_covid_8
		rename			s5bq21__9 ag_covid_9	
		rename 			s5bq21a ag_pr_ban_s
		rename 			s5bq21b ag_pr_ban_m
		rename 			s5bq21c ag_pr_ban_l
		rename 			s5bq21d ag_pr_cass_bag
		rename 			s5bq21e ag_pr_cass_chip
		rename 			s5bq21f ag_pr_cass_flr
		rename 			s5bq21g ag_pr_bean_dry
		rename 			s5bq21h ag_pr_bean_fr
		rename 			s5bq21i ag_pr_maize		
		rename 			s5bq23 ag_sell_norm
		rename 			s5bq24 ag_sell_rev_exp 
	* rename food security
		rename			s8q01 fies_4
		lab var			fies_4 "Worried about not having enough food to eat"
		rename			s8q02 fies_5
		lab var			fies_5 "Unable to eat healthy and nutritious/preferred foods"
		rename			s8q03 fies_6
		lab var			fies_6 "Ate only a few kinds of food"
		rename			s8q04 fies_7
		lab var			fies_7 "Skipped a meal"
		rename			s8q05 fies_8
		lab var			fies_8 "Ate less than you thought you should"
		rename			s8q06 fies_1
		lab var			fies_1 "Ran out of food"
		rename			s8q07 fies_2
		lab var			fies_2 "Hungry but did not eat"
		rename			s8q08 fies_3
		lab var			fies_3 "Went without eating for a whole day"	
* rename concerns
		rename			s9q01 concern_1
		rename			s9q02 concern_2
		gen				have_symp = 1 if s9q03__1 == 1 | s9q03__2 == 1 | s9q03__3 == 1 | ///
							s9q03__4 == 1 | s9q03__5 == 1 | s9q03__6 == 1 | ///
							s9q03__7 == 1 | s9q03__8 == 1
		replace			have_symp = 2 if have_symp == .
		order			have_symp, after(concern_2)	
		rename 			s9q04 have_test
		rename 			s9q05 concern_3
		rename			s9q06 concern_4
		rename			s9q07 concern_5
		rename			s9q08 concern_6
		rename			s9q09 concern_7
		
* save panel
	* gen wave data
		rename			wfinal phw_cs
		lab var			phw "sampling weights - cross section"	
		gen				wave = `w'
		lab var			wave "Wave number"
		order			baseline_hhid wave phw, after(HHID)

	* save file
		save			"$export/wave_0`w'/r`w'", replace

/* END */	