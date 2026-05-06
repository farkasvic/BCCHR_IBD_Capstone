# imports
import pandas as pd
import numpy as np
import country_converter as coco
from pandas.api.types import CategoricalDtype
import os

def main():

    # read in data 
    # change file path according to personal data path
    participant_char = pd.read_csv('/Users/victoriafarkas/Desktop/Capstone/temp_mds_capstone/data/raw/OPT_Participant Characteristics(Sheet1).csv')

    # Resolve non-breaking space issue
    participant_char = participant_char.rename(columns = {
        'Vegetables\xa0(e.g., cabbage, cauliflower):':'Vegetables (e.g., cabbage, cauliflower):',
        'Vegetables (e.g., cabbage, cauliflower):':'Vegetables (e.g., cabbage, cauliflower):.1'
    })  

    # clean all feature names
    participant_char.columns = (
        participant_char.columns
        .str.replace(r'^\d+\.\s*', '', regex=True) # Removes "3. " but ignores "19 years"
        .str.strip()                               # Removes any remaining leading/trailing whitespace
        .str.lower()                               # Converts to lowercase
        .str.replace(r'\s+', '_', regex=True)      # Replaces any internal spaces with hyphens
        .str.replace(':', '')                      # Removes colons
        .str.replace(r'[_\.]+$', '', regex=True)   # Removes trailing underscores or periods
    )

    # participant ID entry cleaning
    participant_char['participant_id'] = (participant_char['participant_id']
                    .str.upper()
                    .str.strip()                # Remove exterior whitespace
                    .str.replace(r'[^\w\s]', '', regex=True) # Remove punctuation
                    .fillna('MISSING')) 

    # event name entry cleaning
    participant_char['event_name'] = (participant_char['event_name']
                    .str.upper()
                    .str.strip()                # Remove exterior whitespace
                    .fillna('MISSING')) 

    # age entry cleaning
    participant_char['age'] = pd.to_numeric(participant_char['age'], errors='coerce') # force to numeric
    participant_char.loc[(participant_char['age'] < 0), 'age'] = np.nan # mask unrealistic ages with NANs

    # impute any missing ages with the median (appropriate where missingness is < 5%)
    median_age = participant_char['age'].median()
    participant_char['age'] = participant_char['age'].fillna(median_age)

    participant_char['age'] = participant_char['age'].astype(int) # cast to int type for cleaner display

    # gender entry cleaning
    # should this be renamed to 'sex' to avoid confusion?
    participant_char['gender'] = participant_char['gender'].str.strip().str.lower()
    participant_char['gender'] = participant_char['gender'].fillna('unknown') # replace missing values

    # map to a binary variable, for future model use
    # participants who answered 'prefer not to say' are also cast as na's
    mapping = {'male': 0, 'female': 1}
    participant_char['gender_code'] = participant_char['gender'].map(mapping).astype('Int64')

    # ethnicity entry cleaning
    ## NOTE: Values are being cast based on the current potential data entries. Data entry should be standardized to avoid creating 
    ## false duplicate levels as there are currently racial and ethnic categpries (e.g. caucasian vs british)
    ## race is a more useful category. Recommendation: collect race not ethnicity as a feature
    participant_char['ethnicity'] = (participant_char['ethnicity']
                    .str.lower()
                    .str.strip()                # Remove exterior whitespace
                    .str.replace(r'[^\w\s]', '', regex=True) # Remove punctuation
                    .fillna('missing')) 

    similar_map = {
        'caucasian': 'white', 'icelandicscottish' : 'white', 'european' : 'white', 'irish': 'white', 'canadianjewish' : 'white', 'caucasien' : 'white',
        'african american': 'black', 'afr am': 'black', 'b': 'black',
        'latino': 'hispanic', 'latina': 'hispanic', 'latinx': 'hispanic',
        'first nations': 'indigenous', 'metis': 'indigenous', 'inuit': 'indigenous'
    }

    participant_char['eth_grouped'] = participant_char['ethnicity'].map(similar_map).fillna(participant_char['ethnicity'])

    # clean country of origin entries, use the country converter package to map to ISO3 codes
    cc = coco.CountryConverter()

    participant_char['country_of_origin'] = participant_char['country_of_origin'].str.strip().str.lower()

    participant_char['coi_iso3_code'] = cc.convert(
        names=participant_char['country_of_origin'].tolist(), 
        to='ISO3', 
        not_found='UNKNOWN'
    )

    # years living in canada entry cleaning
    # ensure that this value is not impossibly larger than the age of the participant. If so, print a warning and set to nan
    impossible_timeline_mask = participant_char['years_living_in_canada'] > participant_char['age']

    violation_count = impossible_timeline_mask.sum()
    if violation_count > 0:
        print(f"WARNING: Found {violation_count} rows where years in Canada > age. Setting to NaN.")

    participant_char.loc[impossible_timeline_mask, 'years_living_in_canada'] = np.nan

    # weight(lbs) and height (cm) entry cleaning
    participant_char['weight_(lbs)'] = pd.to_numeric(participant_char['weight_(lbs)'], errors='coerce')
    participant_char['height_(cm)'] = pd.to_numeric(participant_char['height_(cm)'], errors='coerce')

    participant_char.loc[participant_char['height_(cm)'] <= 0, 'height_(cm)'] = np.nan

    # create a bmi column by converting to kg and m
    weight_kg = participant_char['weight_(lbs)'] * 0.453592
    height_m = participant_char['height_(cm)'] / 100
    participant_char['bmi_1'] = weight_kg / (height_m ** 2)

    # filter out impossible bmi entries
    impossible_bmi_mask = (participant_char['bmi_1'] < 10) | (participant_char['bmi_1'] > 100)

    violation_count = impossible_bmi_mask.sum()
    if violation_count > 0:
        print(f"WARNING: Scrubbing {violation_count} impossible BMI values.")

    participant_char.loc[impossible_bmi_mask, 'bmi_1'] = np.nan

    # exercise history entry cleaning
    participant_char['exercise_history'] = participant_char['exercise_history'].str.strip().str.lower()

    # convert to ordinal feature and handle nans gracefully
    exercise_map = {
        'sedentary lifestyle  - (little to no regular physical activity, spending a significant amount of inactive throughout the day)': 'sedentary',
        'irregular exercise - (engages in physical activity on a sporadic or inconsistent basis)': 'irregular',
        'regular exercise - (at least 150 minutes of moderate to vigorous-intensity aerobic physical activity per week)': 'regular'
    }

    participant_char['exercise_history'] = participant_char['exercise_history'].map(exercise_map)

    # comorbidities entry cleaning: this is a free text field and is impossible to standardize as it is, 
    # so only standard text cleaning will be applied

    # clean the field name
    participant_char = participant_char.rename(columns={'comorbidities_(leave_blank_if_none)': 'comorbidities'})

    participant_char['comorbidities'] = (participant_char['comorbidities']
                    .str.lower()
                    .str.strip()                # Remove exterior whitespace
                    .fillna('none')) 

    # family history of ibd cleaning
    participant_char['family_history_of_ibd'] = participant_char['family_history_of_ibd'].str.strip().str.lower()

    # convert to a binary field
    binary_map = {
        'yes': 1, 
        'no': 0
    }

    participant_char['family_history_of_ibd'] = participant_char['family_history_of_ibd'].map(binary_map)
    participant_char['family_history_of_ibd'] = participant_char['family_history_of_ibd'].astype('Int64')

    # smoking status cleaning
    # clean the field name first
    participant_char = participant_char.rename(columns={'smoklng_status': 'smoking_status'})

    # clean the text entries
    participant_char['smoking_status'] = (
        participant_char['smoking_status']
        .str.strip()
        .str.lower()
        # Safely catch variations like "non smoker" or "non_smoker" and force the hyphen
        .str.replace(r'non[\s_]smoker', 'non-smoker', regex=True) 
    )

    # convert to categorical with levels so that non-smoker is treated as the baseline in models
    smoke_cat_type = CategoricalDtype(
        categories=['non-smoker', 'former smoker', 'current smoker'],
        ordered=True # Change to False if your ML model should NOT treat this as an escalating risk gradient
    )

    participant_char['smoking_status'] = participant_char['smoking_status'].astype(smoke_cat_type)

    # alcohol intake entry cleaning
    participant_char['alcohol_intake'] = (
        participant_char['alcohol_intake']
        .str.strip()
        .str.lower()
    )

    # convert to an ordinal feature
    alcohol_ordinal_map = {
        'non-drinker': 'non-drinker',
        'social drinker (occasional or moderate alcohol consumption in social settings)': 'social drinker',
        'regular drinker (consistent and frequent alcohol consumption)': 'regular drinker'
    }

    participant_char['alcohol_intake'] = participant_char['alcohol_intake'].map(alcohol_ordinal_map)

    # clean various yes/no question columns

    #recreational drug use
    participant_char['recreational_drug_use'] = participant_char['recreational_drug_use'].str.strip().str.lower()
    participant_char['recreational_drug_use'] = participant_char['recreational_drug_use'].map(binary_map).astype('Int64')

    #antibiotics last 2 months
    participant_char = participant_char.rename(columns={'have_you_taken_antibiotics_in_the_last_2_months?': 'antbiotics_last_2months'})
    participant_char['antbiotics_last_2months'] = participant_char['antbiotics_last_2months'].str.strip().str.lower()
    participant_char['antbiotics_last_2months'] = participant_char['antbiotics_last_2months'].map(binary_map).astype('Int64')

    #prebiotics non-digestible fibres
    participant_char = participant_char.rename(columns={'prebiotics_non-digestible_fibres_found_in_supplements_such_as_benefiber,_metamucil,_etc': 'supp_prebiotics'})
    participant_char['supp_prebiotics'] = participant_char['supp_prebiotics'].str.strip().str.lower()
    participant_char['supp_prebiotics'] = participant_char['supp_prebiotics'].map(binary_map).astype('Int64')

    #probiotics
    participant_char = participant_char.rename(columns={'probiotics_live_microorganisms,_like_bacteria_or_yeast,_taken_in_powder_or_capsule_form_such_as_visbiome,_florastor,_etc': 'probiotics'})
    participant_char['probiotics'] = participant_char['probiotics'].str.strip().str.lower()
    participant_char['probiotics'] = participant_char['probiotics'].map(binary_map).astype('Int64')

    #postbiotics
    participant_char = participant_char.rename(columns={'postbiotics_molecules/chemicals_produced_by_probiotics_when_they_ferment_prebiotics_such_as_butyrate,_etc': 'postbiotics'})
    participant_char['postbiotics'] = participant_char['postbiotics'].str.strip().str.lower()
    participant_char['postbiotics'] = participant_char['postbiotics'].map(binary_map).astype('Int64')

    # clean the free text columns for pre/pro/postbiotics

    #rename
    participant_char = participant_char.rename(columns={
        'if_yes,_please_specify_pre-biotics_used': 'brand_prebiotics', # update with exact raw string
        'if_yes,_please_specify_pro-biotics_used': 'brand_probiotics', 
        'if_yes,_please_specify_post-biotic_used': 'brand_postbiotics' 
    })

    #set to none if patient indicated they are not taking any
    participant_char.loc[participant_char['supp_prebiotics'] == 0, 'brand_prebiotics'] = 'none'
    participant_char.loc[participant_char['probiotics'] == 0, 'brand_probiotics'] = 'none'
    participant_char.loc[participant_char['postbiotics'] == 0, 'brand_postbiotics'] = 'none'

    #keep text entries consistently formatted
    participant_char['brand_prebiotics'] = participant_char['brand_prebiotics'].str.lower().str.strip()
    participant_char['brand_probiotics'] = participant_char['brand_probiotics'].str.lower().str.strip()
    participant_char['brand_postbiotics'] = participant_char['brand_postbiotics'].str.lower().str.strip()

    # Ongoing column renaming
    participant_char = participant_char.rename(columns = {
        'participant_id.1':'participant_id_2',
        'general_well-being_(see_descriptors_at_the_end)':'general_well-being',
        'abdominal_pain_(see_descriptors)':'abdominal_pain',
        'number_of_liquid_or_soft_stools_per_day_(yesterday)':'daily_soft_stools',
        'additional_manifestations_(choice=none_=_0)':'no_additional_manifestations',
        'additional_manifestations_(choice=arthalgia_=_1)':'arthalgia',
        'additional_manifestations_(choice=uveitis_=_1)':'uveitis',
        'additional_manifestations_(choice=erythema_nodosum_=_1)':'erythema_nodosum',
        'additional_manifestations_(choice=aphthous_ulcer_=_1)':'aphthous_ulcer',
        'additional_manifestations_(choice=pyoderma_gangrenosum_=_1)':'pyoderma_gangrenosum',
        'additional_manifestations_(choice=anal_fissure_=_1)':'anal_fissure',
        'additional_manifestations_(choice=new_fistula_=_1)':'new_fistula',
        'additional_manifestations_(choice=abscess_=_1)':'abscess',
        'total_harvey_bradshaw_index_score_[sum_of_all_the_above_items]':'harvey_bradshaw_index',
        'changes_in_advanced_therapy_since_the_last_visit':'advanced_therapy_changes',
        'have_you_experienced_gastroenteritis_or_traveled_outside_of_canada_(excluding_the_united_states)_in_the_last_month?_gastroenteritis_inflammation_of_the_stomach_and_intestines,_characterized_by_symptoms_such_as_diarrhea_and_vomiting,_often_caused_by_viral_or_bacterial_infections':'gastroenteritis_outside_canada',
        'are_you_pregnant_or_breastfeeding?':'pregnant_or_breastfeeding',
        'are_you_currently_using_contraception?':'contraception',
        'if_yes,_please_specify_the_method_of_contraception_being_used_(choice=condoms)':'condom_contraceptive',
        'if_yes,_please_specify_the_method_of_contraception_being_used_(choice=oral_contraceptives_(e.g.,_birth_control_pills))':'oral_contraceptive',
        'if_yes,_please_specify_the_method_of_contraception_being_used_(choice=implants_(e.g.,_nexplanon))':'implant_contraceptive',
        'if_yes,_please_specify_the_method_of_contraception_being_used_(choice=intrauterine_(iu)_contraception_(e.g.,_iud))':'intrauterine_contraceptive',
        'is_the_patient_meeting_the_inclusion_and_exclusion_criteria?':'inclusion_exclusion_criteria',
        'how_would_you_describe_your_gender_identity?_for_example,_some_people_identify_as_a_woman,_a_trans_man,_genderqueer,_etc':'gender_identity',
        'have_you_experienced_an_increase_or_decrease_in_weight_over_the_last_6_months?':'6_month_weight_change',
        'if_you_have_experienced_a_change_in_weight,_please_specify_the_amount_(lbs)':'weight_change_amount',
        'have_you_experienced_reduced_oral_intake_over_the_last_month?':'reduced_oral_intake',
        'when_was_your_last_menstrual_cycle_(first_day_of_your_last_period)?_(mm/dd/yy)':'last_menstrual_cycle',
        'if_applicable,_do_gastrointestinal_symptoms,_such_as_pain,_bloating,_diarrhoea_etc.,_worsen_around_the_time_of_your_menstrual_cycle?':'cycle_worsens_symptoms',
        'have_you_ever_tried_modifying_the_texture_of_your_foods_during_a_flare-up?_(e.g.,_blending_solid_foods_such_as_blueberries_into_a_smoothie_instead)':'modifying_food_texture',
        'if_answered_yes_to_the_previous_question,_did_you_find_this_strategy_helpful_in_relieving_some_of_your_flare-up_symptoms?':'modifying_food_texture_helps',
        'fruits_(e.g.,_apples,_oranges)':'fruit_avoidance_active',
        'specify_excluded_fruits_(separate_each_with_a_comma)':'excluded_fruits_active',
        'vegetables_(e.g.,_cabbage,_cauliflower)':'vegetable_avoidance_active',
        'specify_excluded_vegetables_(separate_each_with_a_comma)':'excluded_vegetables_active',
        'whole_grains_(e.g.,_wheat,_oats)':'whole_grain_avoidance_active',
        'specify_excluded_whole_grains_(separate_each_with_a_comma)':'excluded_whole_grains_active',
        'nuts_and_seeds_(e.g.,_cashews,_sesame_seeds)':'nut_seed_avoidance_active',
        'specify_excluded_nuts_and_seeds_(separate_each_with_a_comma)':'excluded_nuts_seeds_active',
        'lactose-containing_foods_(e.g.,_ice_cream,_cheese)':'lactose_avoidance_active',
        'specify_excluded_lactose-containing_foods_(separate_each_with_a_comma)':'excluded_lactose_active',
        'gluten-containing_foods_(e.g.,_bread,_pasta)':'gluten_avoidance_active',
        'specify_excluded_gluten-containing_foods_(separate_each_with_a_comma)':'excluded_gluten_active',
        'spicy_foods_(e.g.,_chili_peppers,_hot_sauces)':'spicy_food_avoidance_active',
        'specify_excluded_spicy_foods_(separate_each_with_a_comma)':'excluded_spicy_foods_active',
        'high_fat_foods_(e.g.,_deep-fried_items,_fatty_cuts_of_meat)':'fat_food_avoidance_active',
        'specify_excluded_high-fat_foods_(separate_each_with_a_comma)':'exclued_fat_foods_active',
        'fruits_(e.g.,_apples,_citrus_fruits)':'fruit_avoidance_rem',
        'specify_excluded_fruits_(separate_each_with_a_comma).1':'excluded_fruits_rem',
        'vegetables_(e.g.,_cabbage,_cauliflower).1':'vegetable_avoidance_rem',
        'specify_excluded_vegetables_(separate_each_with_a_comma).1':'excluded_vegetables_rem',
        'whole_grains_(e.g.,_wheat,_oats).1':'whole_grain_avoidance_rem',
        'specify_excluded_whole_grains_(separate_each_with_a_comma).1':'excluded_whole_grains_rem',
        'nuts_and_seeds_(e.g.,_cashews,_sesame_seeds).1':'nut_seed_avoidance_rem',
        'specify_excluded_nuts_and_seeds_(separate_each_with_a_comma).1':'excluded_nuts_seeds_rem',
        'lactose-containing_foods_(e.g.,_ice_cream,_cheese).1':'lactose_avoidance_rem',
        'specify_excluded_lactose-containing_foods_(separate_each_with_a_comma).1':'excluded_lactose_rem',
        'gluten-containing_foods_(e.g.,_bread,_pasta).1':'gluten_avoidance_rem',
        'specify_excluded_gluten-containing_foods_(separate_each_with_a_comma).1':'excluded_gluten_rem',
        'spicy_foods_(e.g.,_chili_peppers,_hot_sauces).1':'spicy_food_avoidance_rem',
        'specify_excluded_spicy_foods_(separate_each_with_a_comma).1':'excluded_spicy_foods_rem',
        'high_fat_foods_(e.g.,_deep-fried_items,_fatty_cuts_of_meat).1':'fat_food_avoidance_rem',
        'specify_excluded_high-fat_foods_(separate_each_with_a_comma).1':'excluded_fat_foods_rem',
        'i_am_a_picky_eater':'picky_eater',
        'i_dislike_most_of_the_foods_that_other_people_like':'dislike_liked_foods',
        "the_list_of_foods_that_i_like_and_will_eat_is_shorter_than_the_list_of_foods_i_won't_eat":'like_few_foods',
        'i_am_not_very_interested_in_eating_i_seem_to_have_a_smaller_appetite_than_other_people':'small_appetite',
        'i_have_to_push_myself_to_eat_regular_meals_throughout_the_day,_or_to_eat_a_large_enough_amount_of_food_at_meals':'difficulty_eating_regularly',
        'even_when_i_am_eating_a_food_i_really_like,_it_is_hard_for_me_to_eat_a_large_enough_volume_at_meals':'difficulty_eating_high_volumes',
        'i_avoid_or_put_off_eating_because_i_am_afraid_of_gi_discomfort,_chocking_or,_vomiting':'avoid_eating',
        'i_restrict_myself_to_certain_foods_because_i_am_afraid_that_other_foods_will_cause_gi_discomfort,_chocking,_or_vomiting':'restrict_certain_foods',
        'i_eat_small_portions_because_i_am_afraid_of_gi_discomfort,_chocking,_or_vomiting':'eat_small_portions',
        'example_how_often_have_you_felt_unwell_as_a_result_of_your_bowel_problem_in_the_past_2_weeks?':'bowel_ailment_frequency',
        'how_frequent_have_your_bowel_movements_been_during_the_last_two_weeks?_please_indicate_how_frequent_your_bowel_movements_have_been_during_the_last_two_weeks_by_picking_one_of_the_options_from':'bowel_movement_frequency',
        'how_often_has_the_feeling_of_fatigue_or_of_being_tired_and_worn_out_been_a_problem_for_you_during_the_last_2_weeks?_please_indicate_how_often_the_feeling_of_fatigue_or_tiredness_has_been_a_problem_for_you_during_the_last_2_weeks_by_picking_one_of_the_options_from':'fatigue_frequency',
        'how_often_during_the_last_2_weeks_have_you_felt_frustrated,_impatient,_or_restless?_please_choose_an_option_from':'frustration_frequency',
        'how_often_during_the_last_2_weeks_have_you_been_unable_to_attend_school_or_do_your_work_because_of_your_bowel_problem?_please_choose_an_option_from':'work_absence_frequency',
        'how_much_of_the_time_during_the_last_2_weeks_have_your_bowel_movements_been_loose?_please_choose_an_option_from':'loose_movement_frequency',
        'how_much_energy_have_you_had_during_the_last_2_weeks?_please_choose_an_option_from':'energy_level',
        'how_often_during_the_last_2_weeks_did_you_feel_worried_about_the_possibility_of_needing_to_have_surgery_because_of_your_bowel_problem?_please_choose_an_option_from':'surgery_concern_frequency',
        'how_often_during_the_last_2_weeks_have_you_had_to_delay_or_cancel_a_social_engagement_because_of_your_bowel_problem?_please_choose_an_option_from':'social_absence_frequency',
        'how_often_during_the_last_2_weeks_have_you_been_troubled_by_cramps_in_your_abdomen?_please_choose_an_option_from':'abdomen_cramp_frequency',
        'how_often_during_the_last_2_weeks_have_you_felt_generally_unwell?_please_choose_an_option_from':'feeling_unwell_frequency',
        'how_often_during_the_last_2_weeks_have_you_been_troubled_because_of_fear_of_not_finding_a_washroom?_please_choose_an_option_from':'washroom_concern_frequency',
        'how_much_difficulty_have_you_had,_as_a_result_of_your_bowel_problems,_doing_leisure_or_sports_activities_you_would_have_liked_to_have_done_during_the_last_2_weeks?_please_choose_an_option_from':'sport_difficulty_frequency',
        'how_often_during_the_last_2_weeks_have_you_been_troubled_by_pain_in_the_abdomen?_please_choose_an_option_from':'abdomen_pain_frequency',
        "how_often_during_the_last_2_weeks_have_you_had_problems_getting_a_good_night's_sleep,_or_been_troubled_by_waking_up_during_the_night?_please_choose_an_option_from":'sleep_difficulty_frequency',
        'how_often_during_the_last_2_weeks_have_you_felt_depressed_or_discouraged?_please_choose_an_option_from':'depressed_dscouraged_frequency',
        'how_often_during_the_last_2_weeks_have_you_had_to_avoid_attending_events_where_there_was_no_washroom_close_at_hand?_please_choose_an_option_from':'avoid_no_washroom_frequency',
        'overall,_in_the_last_2_weeks,_how_much_of_a_problem_have_you_had_with_passing_large_amounts_of_gas?_please_choose_an_option_from':'excess_gas_frequency',
        'overall,_in_the_last_2_weeks,_how_much_of_a_problem_have_you_had_maintaining_or_getting_to,_the_weight_you_would_like_to_be_at?_please_choose_an_option_from':'desired_weight_challenge_frequency',
        'many_patients_with_bowel_problems_often_have_worries_and_anxieties_related_to_their_illness._these_include_worries_about_getting_cancer,_worries_about_never_feeling_any_better,_and_worries_about_having_a_relapse._in_general,_how_often_during_the_last_2_weeks_have_you_felt_worried_or_anxious?_please_choose_an_option_from':'anxiety_frequency',
        'how_much_of_the_time_during_the_last_2_weeks_have_you_been_troubled_by_a_feeling_of_abdominal_bloating?_please_choose_an_option_from':'abdominal_bloating_frequency',
        'how_often_during_the_last_2_weeks_have_you_felt_relaxed_and_free_of_tension?_please_choose_an_option_from':'relaxed_frequency',
        'how_much_of_the_time_during_the_last_2_weeks_have_you_had_a_problem_with_rectal_bleeding_with_your_bowel_movements?_please_choose_an_option_from':'rectal_bleeding_frequency',
        'how_much_of_the_time_during_the_last_2_weeks_have_you_felt_embarrassed_as_a_result_of_your_bowel_problem?_please_choose_an_option_from':'embarrassment_frequency',
        'how_much_of_the_time_during_the_last_2_weeks_have_you_been_troubled_by_a_feeling_of_having_to_go_to_the_bathroom_even_though_your_bowels_were_empty?_please_choose_an_option_from':'empty_bowel_bathroom_trips',
        'how_much_of_the_time_during_the_last_2_weeks_have_you_felt_tearful_or_upset?_please_choose_an_option_from':'upset_frequency',
        'how_much_of_the_time_during_the_last_2_weeks_have_you_been_troubled_by_accidental_soiling_of_your_underpants?_please_choose_an_option_from':'accidental_soiling_frequency',
        'how_much_of_the_time_during_the_last_2_weeks_have_you_felt_angry_as_a_result_of_your_bowel_problem?_please_choose_an_option_from':'anger_frequency',
        'to_what_extent_has_your_bowel_problem_limited_sexual_activity_during_the_last_2_weeks?_please_choose_an_option_from':'limit_sex_frequency',
        'how_much_of_the_time_during_the_last_2_weeks_have_you_been_troubled_by_nausea_or_feeling_sick_to_your_stomach?_please_choose_an_option_from':'nausea_frequeuncy',
        'how_much_of_the_time_during_the_last_2_weeks_have_you_felt_irritable?_please_choose_an_option_from':'irritation_frequency',
        'how_often_during_the_past_2_weeks_have_you_felt_a_lack_of_understanding_from_others?_please_choose_an_option_from':'lack_of_understanding',
        'how_satisfied,_happy,_or_pleased_have_you_been_with_your_personal_life_during_the_past_2_weeks?_please_choose_one_of_the_following_options_from':'happiness_satisfaction_frequency'
    })

    # Coding well being variable to ordinal with more intuitive ordering (poor = 1 and good = 3)
    participant_char['general_well-being'] = participant_char['general_well-being'].replace({
        'Poor = 2':'Poor = 0',
        'Slightly below Par = 1':'Below Par = 1',
        'Very well = 0':'Very Well = 2'
    })

    # Coding additional manifestation variables to binary
    cols_am = [
        'no_additional_manifestations',
        'arthalgia',
        'uveitis',
        'erythema_nodosum',
        'aphthous_ulcer',
        'pyoderma_gangrenosum',
        'anal_fissure',
        'new_fistula',
        'abscess'
    ]

    for column in cols_am:
        mapping_am = {'Unchecked': 0, 'Checked': 1}
        participant_char[column] = participant_char[column].map(mapping_am)

    # Coding yes/no variables to 0/1 binary
    cols_yes_no = [
        'gastroenteritis_outside_canada',
        'pregnant_or_breastfeeding',
        'contraception',
        'inclusion_exclusion_criteria',
        'reduced_oral_intake',
        'modifying_food_texture',
        'modifying_food_texture_helps'
    ]

    for column in cols_yes_no:
        mapping_yes_no = {'No': 0, 'Yes': 1}
        participant_char[column] = participant_char[column].map(mapping_yes_no)

    # weight(lbs) and height (cm) entry cleaning
    participant_char['weight_(lbs)_.1'] = pd.to_numeric(participant_char['weight_(lbs)_.1'], errors='coerce')
    participant_char['height_(cm)_.1'] = pd.to_numeric(participant_char['height_(cm)_.1'], errors='coerce')

    participant_char.loc[participant_char['height_(cm)_.1'] <= 0, 'height_(cm)_.1'] = np.nan

    # create a bmi column by converting to kg and m
    weight_kg = participant_char['weight_(lbs)_.1'] * 0.453592
    height_m = participant_char['height_(cm)_.1'] / 100
    participant_char['bmi_2'] = weight_kg / (height_m ** 2)

    # filter out impossible bmi entries
    impossible_bmi_mask = (participant_char['bmi_2'] < 10) | (participant_char['bmi_2'] > 100)

    violation_count = impossible_bmi_mask.sum()
    if violation_count > 0:
        print(f"WARNING: Scrubbing {violation_count} impossible BMI values.")

    participant_char.loc[impossible_bmi_mask, 'bmi_2'] = np.nan

    participant_char['weight_change'] = np.select(
        [
            participant_char['6_month_weight_change'] == 'Increase',
            participant_char['6_month_weight_change'] == 'Decrease',
            participant_char['6_month_weight_change'] == 'No change'
        ],
        [
            participant_char['weight_change_amount'],
            -participant_char['weight_change_amount'],
            0
        ],
        default=np.nan
    )

    # Save to CSV
    output_filename = 'cleaned_characteristics.csv'
    save_path = f'data/processed/{output_filename}'
    os.makedirs('data/processed', exist_ok=True)
    participant_char.to_csv(save_path, index=False)
    print(f"Pipeline executed successfully. Cleaned data saved to '{save_path}'.")

if __name__ == "__main__":
    main()