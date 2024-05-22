* Hw2 Macro C. Beatrice Allamand.

clear all
cd "C:\Users\Bea\Dropbox\1st year UCSD\3rd Quarter\Macro C\PS Johannes\Ps2\"
	
	
	* PREAMBLE + IMPORT AND CLEAN DATA
	{
	*Establish color scheme
	global bgcolor "255 255 255"
	global fgcolor "15 60 15"
		/* Decomp Colors */
		global color1 "255 87 51"
		global color2 "0 63 125"
		global color3 "0 128 128"
		
	* Establish some graphing setting
	graph drop _all
	set scheme plotplainblind // Biscoff
	grstyle init
	// Legend settings
	grstyle set legend 6, nobox
	// General plot 
	grstyle color background "${bgcolor}"
	grstyle color major_grid "${fgcolor}"
	grstyle set color "${fgcolor}": axisline major_grid // set axis and grid line color
	grstyle linewidth major_grid thin
	grstyle yesno draw_major_hgrid yes
	grstyle yesno grid_draw_min yes
	grstyle yesno grid_draw_max yes
	grstyle anglestyle vertical_tick horizontal
	
	
	* IMPORT AND CLEAN DATA
	local tsvar "FEDFUNDS UNRATE GDPDEF USRECM"

		foreach v of local tsvar {
				import delimited using "data/`v'.csv", clear case(preserve)
				rename DATE date
				tempfile `v'_dta
				save ``v'_dta', replace
			}
			use `FEDFUNDS_dta', clear
			keep date
			foreach v of local tsvar {
				joinby date using ``v'_dta', unm(b)
				drop _merge
			}
			
			
			gen daten = date(date, "YMD")
			format daten %td
		
		drop if yofd(daten) < 1960  | yofd(daten) > 2023 // data is per quarter in 1947 but per month after 
		gen INFL = 100*(GDPDEF - GDPDEF[_n-12])/GDPDEF[_n-12] //year to year inflation
			la var INFL "Inflation Rate"
			la var FEDFUNDS "Federal Funds Rate"
			la var UNRATE "Unemployment Rate"
			la var daten Date // re=label date 
		local tsvar "FEDFUNDS UNRATE INFL" // Reset local varlist to include created inflation var
	
* Format recession bars: Gen a bar as tall as the higher rate that period when there exists recessions, 0 when not
		
		egen temp1 = rowmax(FEDFUNDS UNRATE USRECM) // Drop GDP deflator out, skipped it from graph since its not a rate
		sum temp1
		local max = ceil(r(max)/5)*5 
		generate recession = `max' if USREC == 1
		drop temp1
		egen temp1 = rowmin(FEDFUNDS UNRATE GDPDEF USRECM)
		sum temp1
		if r(min) < 0 {
			local min = ceil(abs(r(min))/5)*-5
		}
		if r(min) >= 0 {
			local min = floor(abs(r(min))/5)*5
		} //r(min) aqui es 0
			replace  recession = `min' if USREC == 0 //
		drop temp1
		la var recession "NBER Recessions"
	}
	
	* PS QUESTIONS
	
* 1 (a) Plot
	{
	tsset daten
	twoway (area recession daten, color(gs14) base(`min')) ///
		(tsline FEDFUNDS, lc("${color1}") lp(solid))  || ///
		(tsline UNRATE, lc("${color2}") lp(solid) ) || ///
		(tsline INFL, lc("${color3}") lp(solid) ) || ///
		, ///
		title("Monthly U.S. Macroeconomic Indicators, 1960-2023", c("${fgcolor}")) ///
		tlabel(, format(%dCY) labc("${fgcolor}")) ttitle("") ///
		yline(0, lstyle(foreground) lcolor("${fgcolor}") lp(dash)) ///
		caption("Source: FRED." "Note: Shaded regions denote recessions.", c("${fgcolor}")) ///
		ytitle("Percent", c("${fgcolor}")) ///
		name(raw_data___) ///
		legend(on order(2 3 4) pos(6) bmargin(tiny) r(1))  //bplacement(ne) 
graph export "figures/fig1.pdf", replace
	}	
	
* 1 (b) Aggregate series to quarterly frequency
{
	gen dateq = qofd(daten) // quarters since 1960q1

collapse (mean) FEDFUNDS UNRATE INFL (max) recession (last) date daten, by(dateq)
}
* 1 (c) Estimate a VAR with 4 lags from 1960Q1:2007Q4
{
tsset dateq, quarterly
keep if (yofd(daten) >= 1960) & (yofd(daten) <= 2007)

var INFL UNRATE FEDFUNDS, lags(1/4)
irf set var_results, replace
		irf create var_result, step(20) set(var_results) replace
		irf graph irf, impulse(INFL UNRATE FEDFUNDS) response(INFL UNRATE FEDFUNDS) byopts(yrescale) 
			yline(0, lstyle(foreground) lcolor("${fgcolor}") lp(dash)) ///
			name(var_results)
			graph export "figures/fig2.pdf", replace
}

*1 (d) Plot the IRFs from the SVAR with the same ordering
{
matrix A = (1,0,0 \ .,1,0 \ .,.,1)
matrix B = (.,0,0 \ 0,.,0 \ 0,0,.)
svar INFL UNRATE FEDFUNDS, lags(1/4) aeq(A) beq(B)
	irf create mysirf, set(mysirfs) step(20) replace
	irf graph sirf, impulse(INFL UNRATE FEDFUNDS) response(INFL UNRATE FEDFUNDS) ///
			yline(0, lstyle(foreground) lcolor("${fgcolor}") lp(dash)) ///
			name(svar_results_manual)
			graph export "figures/fig3.pdf", replace
}
		
*1. (e) Plot the time series of your identified monetary shocks
{
matrix A = (1,0,0 \ .,1,0 \ .,.,1)
matrix B = (.,0,0 \ 0,.,0 \ 0,0,.)
svar INFL UNRATE FEDFUNDS, lags(1/4) aeq(A) beq(B)
predict resid_INFL , residuals equation(INFL)
predict resid_UNRATE , residuals equation(UNRATE)
predict resid_FEDFUNDS , residuals equation(FEDFUNDS)

drop if resid_FEDFUNDS==.

gen rec=0
replace rec=6 if recession>1
gen min=-4
replace rec=-4 if recession==0
la var rec "NBER Recessions"

twoway (area rec dateq, color(gs14) base(min)) ///
(tsline resid_FEDFUNDS, lc("${color2}") lp(solid)), title("Identified Monetary Shocks", c("${fgcolor}")) ///
		yline(0, lstyle(foreground) lcolor("${fgcolor}") lp(dash)) ///
		ytitle("Shock", c("${fgcolor}")) 	
	graph export "figures/fig4.pdf", replace
}
	
*2 (a) Merge
{
	clear all
	
	* IMPORT AND CLEAN DATA {I imported it again because I dropped some obs}
	{
		{

	local tsvar "FEDFUNDS UNRATE GDPDEF USRECM"

		foreach v of local tsvar {
				import delimited using "data/`v'.csv", clear case(preserve)
				rename DATE date
				tempfile `v'_dta
				save ``v'_dta', replace
			}
			use `FEDFUNDS_dta', clear
			keep date
			foreach v of local tsvar {
				joinby date using ``v'_dta', unm(b)
				drop _merge
			}
			
			
			gen daten = date(date, "YMD")
			format daten %td
		
		drop if yofd(daten) < 1960  | yofd(daten) > 2023 // data is per quarter in 1947 but per month after 
		gen INFL = 100*(GDPDEF - GDPDEF[_n-12])/GDPDEF[_n-12] //year to year inflation
			la var INFL "Inflation Rate"
			la var FEDFUNDS "Federal Funds Rate"
			la var UNRATE "Unemployment Rate"
			la var daten Date // re=label date 
		local tsvar "FEDFUNDS UNRATE INFL" 
		
* Format recession bars: Gen a bar as tall as the higher rate that period when there exists recessions, 0 when not
		
		egen temp1 = rowmax(FEDFUNDS UNRATE USRECM) 
		sum temp1
		local max = ceil(r(max)/5)*5 
		generate recession = `max' if USREC == 1
		drop temp1
		egen temp1 = rowmin(FEDFUNDS UNRATE GDPDEF USRECM)
		sum temp1
		if r(min) < 0 {
			local min = ceil(abs(r(min))/5)*-5
		}
		if r(min) >= 0 {
			local min = floor(abs(r(min))/5)*5
		} //r(min) aqui es 0
			replace  recession = `min' if USREC == 0 //
		drop temp1
		la var recession "NBER Recessions"
	}
	
	* Aggregate series to quarterly frequency
{	gen dateq = qofd(daten) // quarters since 1960q1
collapse (mean) FEDFUNDS UNRATE INFL (max) recession (last) date daten, by(dateq)
}

}

rename dateq date
merge 1:1 date using "C:\Users\Bea\Dropbox\1st year UCSD\3rd Quarter\Macro C\PS Johannes\Ps2\data\Monetary_shocks\RR_monetary_shock_quarterly.dta" ,keepusing(resid_romer)

replace resid_romer=0 if _merge==1

tsset date, quarterly
}

* 2 (b) VAR 8 lags and Romer Shocks (12 lags) IRF 
{
var INFL UNRATE FEDFUNDS, lags(1/8) exog(L(0/12).resid_romer)
irf set var_controls, replace
		irf create var_controls, step(20) set(var_controls) replace
		irf graph irf, impulse(INFL UNRATE FEDFUNDS) response(INFL UNRATE FEDFUNDS) byopts(yrescale) 
			yline(0, lstyle(foreground) lcolor("${fgcolor}") lp(dash)) ///
			name(var_controls)
			graph export "figures/fig5.pdf", replace
		
		irf graph dm, impulse(resid_romer) irf(var_controls)
			graph export "figures/fig5_1.pdf", replace
}

* 2 (c) SVAR 
{
matrix A_ = (1,0,0,0 \ .,1,0,0 \ .,.,1,0 \ .,.,.,1)
matrix B_ = (.,0,0,0 \ 0,.,0,0 \ 0,0,.,0 \ 0,0,0,.)
svar resid_romer INFL UNRATE FEDFUNDS, lags(1/4) aeq(A_) beq(B_)
	irf create mysirf, set(mysirfs) step(20) replace
	irf graph sirf, impulse(resid_romer INFL UNRATE FEDFUNDS) response(resid_romer INFL UNRATE FEDFUNDS) ///
			yline(0, lstyle(foreground) lcolor("${fgcolor}") lp(dash)) ///
			name(svar_results___)
			graph export "figures/fig6.pdf", replace
			
			
			graph export "figures/fig6_onlyRR.pdf", replace // made one only with impulse RR
			
			* Plot fedresid vs romer resid_FEDFUNDS
			twoway (area rec date, color(gs14) base(min)) ///
(tsline resid_FEDFUNDS, lc("${color2}") lp(solid)) ///
(tsline resid_romer, lc("${color1}") lp(solid)), title("Comparison between Identified Residuals (Monetary Shocks) and R&R Shocks", c("${fgcolor}")) ///
		yline(0, lstyle(foreground) lcolor("${fgcolor}") lp(dash)) ///
		ytitle("Shock", c("${fgcolor}")) 	
	graph export "figures/fig7.pdf", replace
}
			
* Extra: Plot fedresid vs romer resid_FEDFUNDS including FEDFUNDS
{
twoway (tsline resid_FEDFUNDS, lc("${color2}") lp(solid)) ///
(tsline resid_romer, lc("${color1}") lp(solid)) /// 
(tsline FEDFUNDS, lc("${color3}") lp(dash)), title("Comparison between Identified Residuals (Monetary Shocks) and R&R Shocks", c("${fgcolor}")) ///
		yline(0, lstyle(foreground) lcolor("${fgcolor}") lp(dash)) ///
		ytitle("Shock", c("${fgcolor}")) 	
	graph export "figures/fig8.pdf", replace
}