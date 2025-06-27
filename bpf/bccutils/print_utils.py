class PrettyPrint:
    @staticmethod
    def dur(durns: float) -> str:
        units = [ "ns", "us", "ms", "s" ]
        conv = 1000
        usel = ""
        for unit in units:
            if durns <= conv:
                usel = unit
                break
            else:
                durns /= conv
        return f"{durns:8.2f} {usel}"

    @staticmethod
    def cnt(cnt: float) -> str:
        units = [ "", "K", "M" ]
        conv = 1000
        usel = ""

        for unit in units:
            if cnt <= conv:
                usel = unit
                break
            else:
                cnt /= conv
        
        return f"{cnt:8.2f} {usel}"