#if "LANG" eq "python"
#define IS_NAN(x) (math.isnan(x))
#define IS_NONE(x) ((x) is None)
#define IS_REAL(x) (not (IS_NONE(x) or IS_NAN(x)))
#define NONE (None)
#define NAN float('nan')
  # ... note that NAN==NAN is false
#endif

#if "LANG" eq "js"
#define IS_NAN(x) (Number.isNaN(x))
#define IS_NONE(x) ((x)==null)
#define IS_REAL(x) (not (IS_NONE(x) or IS_NAN(x)))
#define NONE null
#define NAN (Number.isNaN)
  # ... note that NAN==NAN is false
#endif